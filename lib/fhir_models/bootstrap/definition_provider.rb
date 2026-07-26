require 'json'
require 'tempfile'

module FHIR
  module Boot
    class DefinitionProvider
      extend FHIR::Deprecate

      class << self
        def configure(root:, namespace:, search_parameter_field: 'xpath')
          @root = File.expand_path(root)
          @namespace = namespace
          @search_parameter_field = search_parameter_field.to_s
          unless %w[expression xpath].include?(@search_parameter_field)
            raise ArgumentError, "Unsupported search parameter field: #{@search_parameter_field}"
          end
          @types = nil
          @resources = nil
          @profiles = nil
          @extensions = nil
          @expansions = nil
          @valuesets = nil
          @search_params = nil
          @definition_cache = {}
          @code_cache = {}
          @configuration_verified = false
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

        def type_definition(type_name)
          build_definition(:type, types, type_name)
        end

        def resource_definitions
          resources.select { |resource| resource['kind'] == 'resource' }
        end

        def resource_definition(resource_name)
          build_definition(:resource, resources, resource_name)
        end

        def extension_definition(extension_name)
          build_definition(:extension, extensions, extension_name)
        end

        def basetype(uri)
          definition = find_definition(profiles, uri) || find_definition(extensions, uri)
          basetype_for(definition)
        end

        def profile(uri)
          definition = find_definition(profiles, uri) || find_definition(extensions, uri)
          instantiate(definition)
        end

        def profiles_for_resource(resource_name)
          return nil if resource_name.nil?

          profiles.select do |definition|
            basetype_for(definition) == resource_name
          end.map { |definition| instantiate(definition) }
        end

        def get_profile_class(uri)
          return nil if uri.nil?

          definition = find_definition(profiles, uri) || find_definition(extensions, uri)
          return nil unless definition

          definition = JSON.parse(JSON.generate(definition))
          type = basetype_for(definition)
          id = definition['id'].gsub(/-|_/, '').capitalize
          definition['id'] = type
          generator = FHIR::Boot::Generator.new(
            false,
            definitions: self,
            namespace: namespace.name
          )
          template = generator.generate_class([type], definition)

          file = Tempfile.new(["profile-#{id}", '.rb'])
          namespace.name.split('::').each { |part| file.write("module #{part}\n") }
          file.write("module Profile\n")
          file.write("module #{id}\n")
          file.write(template.to_s)
          (namespace.name.split('::').length + 2).times { file.write("\nend") }
          file.close

          begin
            load file.path
            Object.const_get("#{namespace.name}::Profile::#{id}::#{type}")
          rescue StandardError
            FHIR.logger.error "Failed to generate class for profile #{uri}"
            nil
          ensure
            file.unlink
          end
        end

        def expansions
          @expansions ||= load_bundle('valuesets/expansions.json')
        end

        def valuesets
          @valuesets ||= load_bundle('valuesets/valuesets.json')
        end

        def get_codes(uri)
          return nil if uri.nil?

          normalized_uri = strip_version(uri)
          return @code_cache[normalized_uri] if @code_cache.key?(normalized_uri)

          value_set = expansions.find { |resource| resource['url'] == normalized_uri }
          value_set ||= valuesets.find do |resource|
            resource['resourceType'] == 'ValueSet' && resource['url'] == normalized_uri
          end
          return @code_cache[normalized_uri] = nil unless value_set

          codes = {}
          contains = value_set.dig('expansion', 'contains')
          if contains && normalized_uri != 'http://hl7.org/fhir/ValueSet/c80-doc-typecodes'
            contains.each { |entry| collect_expansion_codes(entry, codes) }
          else
            collect_composed_codes(value_set, codes)
          end
          codes.each_value(&:uniq!)
          @code_cache[normalized_uri] = codes
        end

        def get_display(uri, code)
          return nil if uri.nil? || code.nil?

          expansions.each do |value_set|
            display = find_expansion_display(
              value_set.dig('expansion', 'contains'),
              uri,
              code
            )
            return display if display
          end

          valuesets.each do |resource|
            if resource['resourceType'] == 'CodeSystem' && resource['url'] == uri
              display = find_concept_display(resource['concept'], code)
              return display if display
            elsif resource['resourceType'] == 'ValueSet'
              resource.dig('compose', 'include').to_a.each do |included|
                next unless included['system'] == uri

                display = find_concept_display(included['concept'], code)
                return display if display
              end
            end
          end
          nil
        end

        def search_parameters(type_name)
          return nil if type_name.nil?

          search_params.select do |parameter|
            expression = parameter[@search_parameter_field]
            parameter.fetch('base', []).include?(type_name) &&
              expression &&
              !expression.include?('extension')
          end.map { |parameter| parameter['code'] }
        end

        def types
          @types ||= load_bundle('structures/profiles-types.json')
        end

        def resources
          @resources ||= load_bundle('structures/profiles-resources.json')
        end

        def profiles
          @profiles ||= load_bundle('structures/profiles-others.json')
        end

        def extensions
          @extensions ||= load_bundle('structures/extension-definitions.json')
        end

        def search_params
          @search_params ||= load_bundle('structures/search-parameters.json')
        end

        private

        def load_bundle(relative_path)
          verify_configuration
          filename = File.join(@root, relative_path)
          raise "Definition artifact not found: #{filename}" unless File.file?(filename)

          bundle = JSON.parse(File.open(filename, 'r:UTF-8', &:read))
          unless bundle['resourceType'] == 'Bundle' && bundle['entry'].is_a?(Array)
            raise "Definition artifact is not a FHIR Bundle: #{filename}"
          end

          bundle['entry'].map { |entry| entry['resource'] }.compact
        end

        def verify_configuration
          return if @configuration_verified
          raise 'Definition provider has not been configured' unless @root && @namespace

          if namespace.const_defined?(:FHIR_VERSION, false)
            version_file = File.join(@root, 'version.info')
            raise "Definition version metadata not found: #{version_file}" unless File.file?(version_file)

            version = File.read(version_file).lines.find { |line| line.start_with?('version=') }
            version = version.to_s.split('=', 2).last.to_s.strip
            expected = namespace.const_get(:FHIR_VERSION, false)
            raise "Definitions are FHIR #{version}, expected #{expected}" unless version == expected
          end
          @configuration_verified = true
        end

        def namespace
          raise 'Definition provider has not been configured' unless @namespace

          @namespace
        end

        def build_definition(category, definitions, identifier)
          return nil if identifier.nil?

          key = [category, identifier]
          return @definition_cache[key] if @definition_cache.key?(key)

          @definition_cache[key] = instantiate(find_definition(definitions, identifier))
        end

        def find_definition(definitions, identifier)
          return nil if identifier.nil?

          definitions.find do |definition|
            definition['xmlId'] == identifier ||
              definition['id'] == identifier ||
              definition['name'] == identifier ||
              definition['url'] == identifier
          end
        end

        def instantiate(definition)
          return nil unless definition

          namespace.const_get(:StructureDefinition).new(definition)
        end

        def basetype_for(definition)
          return nil unless definition

          definition['baseType'] ||
            definition['type'] ||
            definition['baseDefinition'].to_s.split('/').last
        end

        def strip_version(uri)
          uri.sub(/\|[A-Za-z0-9.\-]+\z/, '')
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

        def find_expansion_display(concepts, system, code, inherited_system = nil)
          concepts.to_a.each do |concept|
            concept_system = concept['system'] || inherited_system
            return concept['display'] if concept_system == system && concept['code'] == code

            display = find_expansion_display(concept['contains'], system, code, concept_system)
            return display if display
          end
          nil
        end

        def find_concept_display(concepts, code)
          concepts.to_a.each do |concept|
            return concept['display'] if concept['code'] == code

            display = find_concept_display(concept['concept'], code)
            return display if display
          end
          nil
        end
      end

      deprecate :get_primitive_types, :primitive_types
      deprecate :get_complex_types, :complex_types
      deprecate :get_type_definition, :type_definition
      deprecate :load_types, :types
      deprecate :get_resource_definitions, :resource_definitions
      deprecate :get_resource_definition, :resource_definition
      deprecate :load_resources, :resources
      deprecate :load_profiles, :profiles
      deprecate :load_extensions, :extensions
      deprecate :get_extension_definition, :extension_definition
      deprecate :get_basetype, :basetype
      deprecate :get_profile, :profile
      deprecate :get_profiles_for_resource, :profiles_for_resource
      deprecate :load_expansions, :expansions
      deprecate :get_search_parameters, :search_parameters
      deprecate :load_search_params, :search_params

      private_class_method :types, :resources, :profiles, :extensions, :search_params
    end
  end
end
