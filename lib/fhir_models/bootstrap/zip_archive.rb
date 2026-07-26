require 'digest'
require 'open3'

module FHIR
  module Boot
    class ZipArchive
      attr_reader :archive, :entry_root, :entries

      def initialize(archive, entry_root:, expected_checksum:, label:)
        @archive = File.expand_path(archive)
        @entry_root = normalize_entry_root(entry_root)
        @label = label

        raise ArgumentError, "#{label} archive not found: #{@archive}" unless File.file?(@archive)

        checksum = Digest::SHA256.file(@archive).hexdigest
        unless checksum == expected_checksum
          raise ArgumentError, "Unexpected #{label} archive checksum: #{checksum}"
        end

        @entries = list_entries.freeze
        validate_entry_paths!
      end

      def read(relative_path)
        entry = entry_path(relative_path)
        matches = entries.select { |candidate| candidate == entry }
        raise ArgumentError, "Missing #{label} archive entry: #{entry}" if matches.empty?
        raise ArgumentError, "Ambiguous #{label} archive entry: #{entry}" if matches.length > 1

        contents, status = Open3.capture2('unzip', '-p', archive, entry)
        raise "Unable to read #{entry} from #{archive}" unless status.success?

        contents
      end

      def direct_entries(extension:)
        prefix = entry_root.empty? ? '' : "#{entry_root}/"
        selected = entries.select do |entry|
          next false unless entry.start_with?(prefix)

          relative = entry.delete_prefix(prefix)
          !relative.empty? && !relative.include?('/') && relative.end_with?(extension)
        end

        duplicates = selected.group_by { |entry| File.basename(entry) }
                             .select { |_basename, matches| matches.length > 1 }
        unless duplicates.empty?
          names = duplicates.keys.sort.join(', ')
          raise ArgumentError, "Duplicate #{label} archive entries: #{names}"
        end

        selected.sort
      end

      private

      attr_reader :label

      def list_entries
        output, status = Open3.capture2('unzip', '-Z1', archive)
        raise "Unable to list #{label} archive entries from #{archive}" unless status.success?

        output.lines.map(&:strip)
      end

      def normalize_entry_root(root)
        raise ArgumentError, 'ZIP entry root is required' if root.nil?

        normalized = root.to_s.sub(%r{/+\z}, '')
        validate_relative_path!(normalized, allow_empty: true)
        normalized
      end

      def entry_path(relative_path)
        validate_relative_path!(relative_path)
        return relative_path if entry_root.empty?

        "#{entry_root}/#{relative_path}"
      end

      def validate_entry_paths!
        entries.each { |entry| validate_relative_path!(entry) }
      end

      def validate_relative_path!(path, allow_empty: false)
        invalid = path.nil? ||
                  (!allow_empty && path.empty?) ||
                  path.start_with?('/') ||
                  path.include?('\\') ||
                  path.split('/').include?('..') ||
                  path.match?(%r{\A[A-Za-z]:})
        raise ArgumentError, "Unsafe ZIP archive path: #{path.inspect}" if invalid
      end
    end
  end
end
