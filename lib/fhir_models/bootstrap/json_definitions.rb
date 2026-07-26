require 'json'
require 'fileutils'
require_relative 'zip_archive'

module FHIR
  module Boot
    class JsonDefinitions
      RUNTIME_STRUCTURE_FILES = %w[
        profiles-types.json
        profiles-resources.json
        profiles-others.json
        extension-definitions.json
        search-parameters.json
      ].freeze

      attr_reader :archive, :entry_root, :expansions

      def initialize(archive, expansions:, entry_root:, expected_checksum:)
        @archive = File.expand_path(archive)
        @entry_root = entry_root
        @expansions = File.expand_path(expansions)
        raise ArgumentError, "Expansion bundle not found: #{@expansions}" unless File.file?(@expansions)

        @source = ZipArchive.new(
          @archive,
          entry_root: entry_root,
          expected_checksum: expected_checksum,
          label: 'FHIR definitions'
        )
        @cache = {}
      end

      def primitive_types
        types.select { |type| type['id'].start_with?(*('a'..'z').to_a) }
      end

      def complex_types
        types.select do |type|
          type['id'].start_with?(*('A'..'Z').to_a) &&
            type.dig('snapshot', 'element', 0, 'path') == type['id']
        end
      end

      def resource_definitions
        resources.select { |resource| resource['kind'] == 'resource' }
      end

      def search_parameters(type_name)
        return nil if type_name.nil?

        search_params.select do |parameter|
          parameter['base'].include?(type_name) &&
            parameter['xpath'] &&
            !parameter['xpath'].include?('extension')
        end.map { |parameter| parameter['code'] }
      end

      def get_codes(uri)
        return nil if uri.nil?
        return @cache[uri] if @cache.key?(uri)

        value_set = expanded_valuesets.find { |resource| resource['url'] == uri }
        value_set ||= valuesets.find do |resource|
          resource['resourceType'] == 'ValueSet' && resource['url'] == uri
        end
        return @cache[uri] = nil unless value_set

        codes = {}
        contains = value_set.dig('expansion', 'contains')
        if contains && uri != 'http://hl7.org/fhir/ValueSet/c80-doc-typecodes'
          contains.each { |entry| collect_expansion_codes(entry, codes) }
        else
          collect_composed_codes(value_set, codes)
        end
        codes.each_value(&:uniq!)
        @cache[uri] = codes
      end

      def write_runtime_artifacts(root)
        structures = File.join(root, 'structures')
        valuesets = File.join(root, 'valuesets')
        FileUtils.rm_rf([structures, valuesets])
        FileUtils.mkdir_p([structures, valuesets])

        RUNTIME_STRUCTURE_FILES.each do |filename|
          destination = File.join(structures, filename)
          copy_archived_artifact(filename, destination)
          Preprocess.pre_process_bundle(destination)
        end

        valueset_destination = File.join(valuesets, 'valuesets.json')
        copy_archived_artifact('valuesets.json', valueset_destination)
        Preprocess.pre_process_bundle(valueset_destination)

        expansion_destination = File.join(valuesets, 'expansions.json')
        FileUtils.cp(expansions, expansion_destination)
        Preprocess.pre_process_bundle(expansion_destination)

        copy_archived_artifact(
          'version.info',
          File.join(root, 'version.info'),
          normalize_line_endings: true
        )
      end

      private

      def types
        @types ||= load_archived_bundle('profiles-types.json')
      end

      def resources
        @resources ||= load_archived_bundle('profiles-resources.json')
      end

      def search_params
        @search_params ||= load_archived_bundle('search-parameters.json')
      end

      def profiles
        @profiles ||= load_archived_bundle('profiles-others.json').select do |resource|
          resource['resourceType'] == 'StructureDefinition'
        end
      end

      def extensions
        @extensions ||= load_archived_bundle('extension-definitions.json').select do |resource|
          resource['resourceType'] == 'StructureDefinition'
        end
      end

      def valuesets
        @valuesets ||= load_archived_bundle('valuesets.json')
      end

      def expanded_valuesets
        @expanded_valuesets ||= load_bundle(File.open(expansions, 'r:UTF-8', &:read))
      end

      def load_archived_bundle(filename)
        load_bundle(@source.read(filename))
      end

      def load_bundle(json)
        bundle = JSON.parse(json)
        unless bundle['resourceType'] == 'Bundle' && bundle['entry'].is_a?(Array)
          raise ArgumentError, 'Definition artifact is not a FHIR Bundle'
        end

        bundle['entry'].map { |entry| entry['resource'] }.compact
      end

      def copy_archived_artifact(filename, destination, normalize_line_endings: false)
        contents = @source.read(filename)

        if normalize_line_endings
          contents = contents.gsub("\r\n", "\n")
          contents += "\n" unless contents.end_with?("\n")
        end
        File.binwrite(destination, contents)
      end

      def collect_expansion_codes(entry, codes, inherited_system = nil)
        system = entry['system'] || inherited_system
        (codes[system] ||= []) << entry['code'] if system && entry['code']
        entry.fetch('contains', []).each do |child|
          collect_expansion_codes(child, codes, system)
        end
      end

      def collect_composed_codes(value_set, codes)
        value_set.dig('compose', 'include').to_a.each do |group|
          system = group['system']
          next unless system

          codes[system] ||= []
          if group['concept']
            group['concept'].each { |concept| codes[system] << concept['code'] }
          elsif group.keys == ['system']
            valuesets.select do |resource|
              resource['resourceType'] == 'CodeSystem' && resource['url'] == system
            end.each do |code_system|
              collect_code_system_codes(code_system['concept'], codes[system])
            end
          end
        end
      end

      def collect_code_system_codes(concepts, codes)
        concepts.to_a.each do |concept|
          codes << concept['code'] if concept['code']
          collect_code_system_codes(concept['concept'], codes)
        end
      end

    end
  end
end
