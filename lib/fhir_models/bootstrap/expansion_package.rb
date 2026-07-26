require 'fileutils'
require_relative 'npm_package'

module FHIR
  module Boot
    class ExpansionPackage < NpmPackage
      R5_SOURCE_URL = 'https://hl7.org/fhir/R5/hl7.fhir.r5.expansions.tgz'.freeze
      R5_PACKAGE_NAME = 'hl7.fhir.r5.expansions'.freeze
      R5_PACKAGE_VERSION = '5.0.0'.freeze
      R5_FHIR_VERSIONS = ['5.0.0'].freeze
      R5_SHA256 = 'f2fe00691fd8dfbe39193b46fb3988d8e128b6a37e1d654454de065ef675c32b'.freeze

      VALUE_SET_PATH = %r{\Apackage/ValueSet-[^/]+\.json\z}.freeze

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
          'id' => "#{package_metadata.fetch('name')}-#{package_metadata.fetch('version')}",
          'type' => 'collection',
          'entry' => value_sets.map do |item|
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
        path.match?(VALUE_SET_PATH)
      end

      private

      def value_sets
        canonical_urls = {}
        resources = files.keys.grep(VALUE_SET_PATH).map do |path|
          resource = parse_json(path, files.fetch(path))
          unless resource['resourceType'] == 'ValueSet'
            raise ArgumentError, "Unexpected resource type in #{path}: #{resource['resourceType'].inspect}"
          end

          canonical_url = resource['url']
          if !canonical_url.is_a?(String) || canonical_url.empty?
            raise ArgumentError, "ValueSet in #{path} has no canonical URL"
          end
          if canonical_urls.key?(canonical_url)
            raise ArgumentError, "Duplicate ValueSet canonical URL: #{canonical_url}"
          end

          canonical_urls[canonical_url] = path
          { path: path, resource: resource }
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
    end
  end
end
