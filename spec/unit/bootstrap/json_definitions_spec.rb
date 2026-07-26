require 'spec_helper'
require 'digest'
require 'fileutils'
require 'tmpdir'

describe FHIR::Boot::JsonDefinitions do
  let(:bundle) do
    JSON.generate(
      'resourceType' => 'Bundle',
      'type' => 'collection',
      'entry' => [
        {
          'resource' => {
            'resourceType' => 'StructureDefinition',
            'id' => 'Patient',
            'kind' => 'resource'
          }
        }
      ]
    )
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      @expansions = File.join(directory, 'expansions.json')
      File.write(@expansions, JSON.generate('resourceType' => 'Bundle', 'entry' => []))
      example.run
    end
  end

  it 'reads definitions from an explicitly configured nested entry root' do
    archive = build_zip('nested.zip', 'definitions.json/profiles-resources.json' => bundle)
    definitions = definitions_for(archive, entry_root: 'definitions.json')

    resources = definitions.send(:load_archived_bundle, 'profiles-resources.json')

    expect(resources.map { |resource| resource['id'] }).to eq ['Patient']
  end

  it 'reads definitions from an explicitly configured ZIP root' do
    archive = build_zip('root.zip', 'profiles-resources.json' => bundle)
    definitions = definitions_for(archive, entry_root: '')

    resources = definitions.send(:load_archived_bundle, 'profiles-resources.json')

    expect(resources.map { |resource| resource['id'] }).to eq ['Patient']
  end

  it 'rejects a missing entry under the configured root' do
    archive = build_zip('missing.zip', 'other/profiles-resources.json' => bundle)
    definitions = definitions_for(archive, entry_root: 'definitions.json')

    expect do
      definitions.send(:load_archived_bundle, 'profiles-resources.json')
    end.to raise_error(ArgumentError, /Missing FHIR definitions archive entry/)
  end

  it 'rejects duplicate exact entries' do
    archive = build_zip('duplicate.zip', 'definitions.json/profiles-resources.json' => bundle)
    definitions = definitions_for(archive, entry_root: 'definitions.json')
    source = definitions.instance_variable_get(:@source)
    duplicate = 'definitions.json/profiles-resources.json'
    source.instance_variable_set(:@entries, [duplicate, duplicate])

    expect do
      definitions.send(:load_archived_bundle, 'profiles-resources.json')
    end.to raise_error(ArgumentError, /Ambiguous FHIR definitions archive entry/)
  end

  it 'does not select a similarly named entry from another directory' do
    archive = build_zip(
      'similar.zip',
      'definitions.json/nested/profiles-resources.json' => bundle,
      'other/profiles-resources.json' => bundle
    )
    definitions = definitions_for(archive, entry_root: 'definitions.json')

    expect do
      definitions.send(:load_archived_bundle, 'profiles-resources.json')
    end.to raise_error(ArgumentError, /Missing FHIR definitions archive entry/)
  end

  it 'rejects an incorrect checksum before listing archive entries' do
    archive = File.join(@directory, 'not-a-zip.zip')
    File.write(archive, 'not a ZIP archive')

    expect do
      described_class.new(
        archive,
        expansions: @expansions,
        entry_root: '',
        expected_checksum: '0' * 64
      )
    end.to raise_error(ArgumentError, /Unexpected FHIR definitions archive checksum/)
  end

  it 'preserves the existing R4B runtime artifact output' do
    entries = described_class::RUNTIME_STRUCTURE_FILES.each_with_object({}) do |filename, result|
      result["definitions.json/#{filename}"] = bundle
    end
    entries['definitions.json/valuesets.json'] = bundle
    entries['definitions.json/version.info'] = "version=4.3.0\r\n"
    archive = build_zip('r4b.zip', entries)
    definitions = definitions_for(archive, entry_root: 'definitions.json')
    actual = File.join(@directory, 'actual')
    expected = File.join(@directory, 'expected')

    definitions.write_runtime_artifacts(actual)
    write_legacy_runtime_artifacts(archive, expected)

    expect(directory_contents(actual)).to eq directory_contents(expected)
  end

  def definitions_for(archive, entry_root:)
    described_class.new(
      archive,
      expansions: @expansions,
      entry_root: entry_root,
      expected_checksum: Digest::SHA256.file(archive).hexdigest
    )
  end

  def build_zip(filename, entries)
    source = File.join(@directory, "#{filename}-source")
    FileUtils.mkdir_p(source)
    entries.each do |entry, contents|
      path = File.join(source, entry)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, contents)
    end

    archive = File.join(@directory, filename)
    Dir.chdir(source) do
      success = system('zip', '-q', archive, *entries.keys)
      raise 'Unable to build ZIP test fixture' unless success
    end
    archive
  end

  def write_legacy_runtime_artifacts(archive, root)
    structures = File.join(root, 'structures')
    valuesets = File.join(root, 'valuesets')
    FileUtils.mkdir_p([structures, valuesets])

    described_class::RUNTIME_STRUCTURE_FILES.each do |filename|
      destination = File.join(structures, filename)
      extract(archive, "definitions.json/#{filename}", destination)
      FHIR::Boot::Preprocess.pre_process_bundle(destination)
    end
    extract(archive, 'definitions.json/valuesets.json', File.join(valuesets, 'valuesets.json'))
    FHIR::Boot::Preprocess.pre_process_bundle(File.join(valuesets, 'valuesets.json'))
    FileUtils.cp(@expansions, File.join(valuesets, 'expansions.json'))
    FHIR::Boot::Preprocess.pre_process_bundle(File.join(valuesets, 'expansions.json'))
    extract(archive, 'definitions.json/version.info', File.join(root, 'version.info'))
    version = File.binread(File.join(root, 'version.info')).gsub("\r\n", "\n")
    version += "\n" unless version.end_with?("\n")
    File.binwrite(File.join(root, 'version.info'), version)
  end

  def extract(archive, entry, destination)
    contents, status = Open3.capture2('unzip', '-p', archive, entry)
    raise "Unable to extract #{entry}" unless status.success?

    File.binwrite(destination, contents)
  end

  def directory_contents(root)
    Dir.glob(File.join(root, '**', '*')).select { |path| File.file?(path) }
       .sort.each_with_object({}) do |path, contents|
      contents[path.delete_prefix("#{root}/")] = File.binread(path)
    end
  end
end
