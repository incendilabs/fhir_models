require 'digest'
require 'json'
require 'rubygems/package'
require 'zlib'

module FHIR
  module Boot
    class NpmPackage
      PACKAGE_METADATA_PATH = 'package/package.json'.freeze

      attr_reader :archive, :package_metadata

      def initialize(
        archive,
        expected_name:,
        expected_version:,
        expected_fhir_versions:,
        expected_checksum:
      )
        @archive = File.expand_path(archive)
        @expected_name = expected_name
        @expected_version = expected_version
        @expected_fhir_versions = expected_fhir_versions.sort

        raise ArgumentError, "FHIR package not found: #{@archive}" unless File.file?(@archive)

        checksum = Digest::SHA256.file(@archive).hexdigest
        unless checksum == expected_checksum
          raise ArgumentError, "Unexpected FHIR package checksum: #{checksum}"
        end

        @files = read_files
        @package_metadata = parse_json(PACKAGE_METADATA_PATH, @files[PACKAGE_METADATA_PATH])
        validate_package_metadata!
      end

      protected

      attr_reader :files

      def selected_path?(_path)
        false
      end

      def parse_json(path, contents)
        raise ArgumentError, "Missing FHIR package entry: #{path}" if contents.nil?

        JSON.parse(contents)
      rescue JSON::ParserError => e
        raise ArgumentError, "Malformed JSON in FHIR package entry #{path}: #{e.message}"
      end

      private

      def read_files
        selected = {}
        paths = {}

        Zlib::GzipReader.open(archive) do |gzip|
          Gem::Package::TarReader.new(gzip) do |tar|
            tar.each do |entry|
              path = entry.full_name
              validate_archive_path!(path)
              raise ArgumentError, "Duplicate FHIR package entry: #{path}" if paths.key?(path)

              paths[path] = true
              next if entry.directory?
              unless entry.file?
                raise ArgumentError, "Unsupported FHIR package entry type: #{path}"
              end
              next unless path == PACKAGE_METADATA_PATH || selected_path?(path)

              selected[path] = entry.read
            end
          end
        end

        selected
      rescue Zlib::GzipFile::Error, Gem::Package::TarInvalidError => e
        raise ArgumentError, "Unable to read FHIR package #{archive}: #{e.message}"
      end

      def validate_archive_path!(path)
        invalid = path.nil? ||
                  path.empty? ||
                  path.start_with?('/') ||
                  path.include?('\\') ||
                  path.split('/').include?('..') ||
                  path.match?(%r{\A[A-Za-z]:})
        raise ArgumentError, "Unsafe FHIR package path: #{path.inspect}" if invalid
      end

      def validate_package_metadata!
        validate_metadata_value!('name', package_metadata['name'], @expected_name)
        validate_metadata_value!('version', package_metadata['version'], @expected_version)

        actual_versions = package_metadata['fhirVersions']
        unless actual_versions.is_a?(Array) && actual_versions.all? { |version| version.is_a?(String) }
          raise ArgumentError, 'FHIR package fhirVersions must be an array of strings'
        end
        return if actual_versions.sort == @expected_fhir_versions

        raise ArgumentError,
              "Unexpected FHIR package fhirVersions: #{actual_versions.inspect}"
      end

      def validate_metadata_value!(field, actual, expected)
        return if actual == expected

        raise ArgumentError, "Unexpected FHIR package #{field}: #{actual.inspect}"
      end
    end
  end
end
