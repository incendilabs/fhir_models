require 'spec_helper'
require 'digest'
require 'fileutils'
require 'tmpdir'

describe FHIR::Boot::SchemaArchive do
  let(:schema) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:annotation>
          <xs:documentation>Removed during preprocessing.</xs:documentation>
        </xs:annotation>
        <xs:element name="resource" type="xs:string"/>
      </xs:schema>
    XML
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  it 'extracts the configured R4B nested schema layout' do
    archive = build_zip(
      'r4b.zip',
      'fhir-all-xsd/fhir-all.xsd' => schema,
      'fhir-all-xsd/patient.xsd' => schema
    )
    destination = File.join(@directory, 'r4b-schema')

    archive_for(archive, entry_root: 'fhir-all-xsd').extract(destination)

    expect(schema_files(destination)).to eq %w[fhir-all.xsd patient.xsd]
  end

  it 'extracts the configured R5 ZIP-root schema layout' do
    archive = build_zip(
      'r5.zip',
      'fhir-all.xsd' => schema,
      'subscriptiontopic.xsd' => schema
    )
    destination = File.join(@directory, 'r5-schema')

    archive_for(archive, entry_root: '').extract(destination)

    expect(schema_files(destination)).to eq %w[fhir-all.xsd subscriptiontopic.xsd]
  end

  it 'rejects an incorrect checksum before listing archive entries' do
    archive = File.join(@directory, 'not-a-zip.zip')
    File.write(archive, 'not a ZIP archive')

    expect do
      described_class.new(
        archive,
        entry_root: '',
        expected_checksum: '0' * 64
      )
    end.to raise_error(ArgumentError, /Unexpected FHIR XML schema archive checksum/)
  end

  it 'rejects an incorrect configured entry root' do
    archive = build_zip('wrong-root.zip', 'fhir-all.xsd' => schema)

    expect do
      archive_for(archive, entry_root: 'fhir-all-xsd')
        .extract(File.join(@directory, 'schema'))
    end.to raise_error(ArgumentError, /No FHIR XML schemas found/)
  end

  it 'rejects archives without fhir-all.xsd' do
    archive = build_zip('missing-fhir-all.zip', 'patient.xsd' => schema)

    expect do
      archive_for(archive, entry_root: '').extract(File.join(@directory, 'schema'))
    end.to raise_error(ArgumentError, /does not contain fhir-all\.xsd/)
  end

  it 'rejects duplicate schema basenames' do
    archive = build_zip('duplicate.zip', 'fhir-all.xsd' => schema)
    source = archive_for(archive, entry_root: '')
    zip_archive = source.instance_variable_get(:@source)
    zip_archive.instance_variable_set(:@entries, %w[fhir-all.xsd fhir-all.xsd])

    expect do
      source.extract(File.join(@directory, 'schema'))
    end.to raise_error(ArgumentError, /Duplicate FHIR XML schema archive entries/)
  end

  it 'rejects path traversal entries anywhere in the archive' do
    archive = build_unsafe_zip

    expect do
      archive_for(archive, entry_root: '')
    end.to raise_error(ArgumentError, /Unsafe ZIP archive path/)
  end

  it 'writes only direct XSD files under the configured entry root' do
    archive = build_zip(
      'selection.zip',
      'schemas/fhir-all.xsd' => schema,
      'schemas/patient.xsd' => schema,
      'schemas/readme.txt' => 'ignored',
      'schemas/nested/ignored.xsd' => schema,
      'other/ignored.xsd' => schema
    )
    destination = File.join(@directory, 'schema')

    archive_for(archive, entry_root: 'schemas').extract(destination)

    expect(schema_files(destination)).to eq %w[fhir-all.xsd patient.xsd]
  end

  it 'preprocesses every written schema' do
    archive = build_zip(
      'preprocess.zip',
      'fhir-all.xsd' => schema,
      'patient.xsd' => schema
    )
    destination = File.join(@directory, 'schema')
    processed = []
    original = FHIR::Boot::Preprocess.method(:pre_process_schema)
    allow(FHIR::Boot::Preprocess).to receive(:pre_process_schema) do |path|
      processed << File.basename(path)
      original.call(path)
    end

    archive_for(archive, entry_root: '').extract(destination)

    expect(processed.sort).to eq %w[fhir-all.xsd patient.xsd]
    schema_files(destination).each do |filename|
      expect(File.read(File.join(destination, filename))).not_to include 'xs:annotation'
    end
  end

  def archive_for(archive, entry_root:)
    described_class.new(
      archive,
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

  def build_unsafe_zip
    source = File.join(@directory, 'unsafe-source')
    FileUtils.mkdir_p(source)
    File.binwrite(File.join(@directory, 'unsafe.xsd'), schema)
    archive = File.join(@directory, 'unsafe.zip')
    Dir.chdir(source) do
      success = system('zip', '-q', archive, '../unsafe.xsd')
      raise 'Unable to build unsafe ZIP test fixture' unless success
    end
    archive
  end

  def schema_files(destination)
    Dir.glob(File.join(destination, '*.xsd')).map { |path| File.basename(path) }.sort
  end
end
