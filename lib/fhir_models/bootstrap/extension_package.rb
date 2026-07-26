require 'fileutils'
require_relative 'npm_package'

module FHIR
  module Boot
    class ExtensionPackage < NpmPackage
      R5_SOURCE_URL = 'https://packages2.fhir.org/packages/hl7.fhir.uv.extensions.r5/1.0.0'.freeze
      R5_PACKAGE_NAME = 'hl7.fhir.uv.extensions.r5'.freeze
      R5_PACKAGE_VERSION = '1.0.0'.freeze
      R5_FHIR_VERSIONS = ['5.0.0'].freeze
      R5_SHA256 = 'b60edfadff29ef16a5a253083f33b1c6f83646b3cda1691745453162edbd86b9'.freeze

      STRUCTURE_DEFINITION_PATH = %r{\Apackage/StructureDefinition-[^/]+\.json\z}.freeze

      def self.r5(archive)
        new(
          archive,
          expected_name: R5_PACKAGE_NAME,
          expected_version: R5_PACKAGE_VERSION,
          expected_fhir_versions: R5_FHIR_VERSIONS,
          expected_checksum: R5_SHA256
        )
      end

      def bundle
        @bundle ||= {
          'resourceType' => 'Bundle',
          'id' => "#{package_metadata.fetch('name')}-#{package_metadata.fetch('version')}-extensions",
          'type' => 'collection',
          'entry' => extensions.map do |item|
            {
              'fullUrl' => item.fetch(:resource).fetch('url'),
              'resource' => item.fetch(:resource)
            }
          end
        }
      end

      def write(destination)
        output = "#{JSON.pretty_generate(bundle)}\n"
        FileUtils.mkdir_p(File.dirname(destination))
        File.binwrite(destination, output)
      end

      protected

      def selected_path?(path)
        path.match?(STRUCTURE_DEFINITION_PATH)
      end

      private

      def extensions
        canonical_urls = {}
        resources = files.keys.grep(STRUCTURE_DEFINITION_PATH).each_with_object([]) do |path, result|
          resource = parse_json(path, files.fetch(path))
          unless resource['resourceType'] == 'StructureDefinition'
            raise ArgumentError, "Unexpected resource type in #{path}: #{resource['resourceType'].inspect}"
          end

          next unless extension_definition?(resource)

          validate_extension_fhir_version!(resource, path)
          canonical_url = resource['url']
          if !canonical_url.is_a?(String) || canonical_url.empty?
            raise ArgumentError, "Extension StructureDefinition in #{path} has no canonical URL"
          end
          if canonical_urls.key?(canonical_url)
            raise ArgumentError, "Duplicate extension canonical URL: #{canonical_url}"
          end

          canonical_urls[canonical_url] = path
          result << { path: path, resource: resource }
        end

        resources.sort_by do |item|
          resource = item.fetch(:resource)
          [
            resource.fetch('url'),
            resource.fetch('version', ''),
            resource.fetch('id', ''),
            item.fetch(:path)
          ]
        end
      end

      def extension_definition?(resource)
        return false unless resource['type'] == 'Extension'
        return false if resource['abstract'] == true || resource['exampleBoolean'] == true

        unless resource['kind'] == 'complex-type' && resource['derivation'] == 'constraint'
          raise ArgumentError,
                "Unexpected extension StructureDefinition shape: #{resource['url'].inspect}"
        end
        true
      end

      def validate_extension_fhir_version!(resource, path)
        fhir_version = resource['fhirVersion']
        return if package_metadata.fetch('fhirVersions').include?(fhir_version)

        raise ArgumentError,
              "Incompatible extension fhirVersion in #{path}: #{fhir_version.inspect}"
      end
    end
  end
end
