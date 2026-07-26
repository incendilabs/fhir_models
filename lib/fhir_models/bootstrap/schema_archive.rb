require 'fileutils'
require 'tmpdir'
require_relative 'preprocess'
require_relative 'zip_archive'

module FHIR
  module Boot
    class SchemaArchive
      def initialize(archive, entry_root:, expected_checksum:)
        @source = ZipArchive.new(
          archive,
          entry_root: entry_root,
          expected_checksum: expected_checksum,
          label: 'FHIR XML schema'
        )
      end

      def extract(destination)
        entries = @source.direct_entries(extension: '.xsd')
        raise ArgumentError, 'No FHIR XML schemas found under the configured entry root' if entries.empty?

        basenames = entries.map { |entry| File.basename(entry) }
        unless basenames.include?('fhir-all.xsd')
          raise ArgumentError, 'FHIR XML schema archive does not contain fhir-all.xsd'
        end

        destination = File.expand_path(destination)
        parent = File.dirname(destination)
        FileUtils.mkdir_p(parent)
        working = Dir.mktmpdir(".#{File.basename(destination)}-", parent)

        begin
          entries.each do |entry|
            filename = File.basename(entry)
            schema = File.join(working, filename)
            File.binwrite(schema, @source.read(filename))
            Preprocess.pre_process_schema(schema)
          end

          FileUtils.rm_rf(destination)
          FileUtils.mv(working, destination)
          working = nil
        ensure
          FileUtils.rm_rf(working) if working
        end

        destination
      end
    end
  end
end
