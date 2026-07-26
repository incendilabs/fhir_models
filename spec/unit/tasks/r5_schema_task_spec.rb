require 'spec_helper'
require 'fileutils'
require 'rake'
require 'tmpdir'

unless Rake::Task.task_defined?('fhir:generate_r5_schema')
  load File.expand_path('../../../lib/fhir_models/tasks/tasks.rake', __dir__)
end

describe 'FHIR R5 schema generation' do
  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  it 'requires an explicit schema archive argument' do
    task = Rake::Task['fhir:generate_r5_schema']

    task.reenable
    expect { task.invoke }.to raise_error(
      ArgumentError,
      /Provide the R5 schema archive path/
    )
  end

  it 'configures the official R5 ZIP-root schema layout' do
    archive = File.join(@directory, 'fhir-all-xsd.zip')
    destination = File.join(@directory, 'schema')
    schema_archive = instance_double(FHIR::Boot::SchemaArchive)
    allow(FHIR::Boot::SchemaArchive).to receive(:new).and_return(schema_archive)
    allow(schema_archive).to receive(:extract).with(destination)

    FHIR::Tasks.generate_r5_schema(
      schema_archive: archive,
      destination: destination
    )

    expect(FHIR::Boot::SchemaArchive).to have_received(:new).with(
      archive,
      entry_root: '',
      expected_checksum: FHIR::R5::SCHEMA_SHA256
    )
  end

  it 'preserves existing output when the schema checksum is incorrect' do
    destination = File.join(@directory, 'schema')
    FileUtils.mkdir_p(destination)
    File.write(File.join(destination, 'sentinel.txt'), 'preserved')
    archive = File.join(@directory, 'fhir-all-xsd.zip')
    File.write(archive, 'not a schema archive')

    expect do
      FHIR::Tasks.generate_r5_schema(
        schema_archive: archive,
        destination: destination
      )
    end.to raise_error(
      ArgumentError,
      /Unexpected FHIR XML schema archive checksum/
    )

    expect(File.read(File.join(destination, 'sentinel.txt'))).to eq 'preserved'
  end

  it 'does not fall back when the configured R5 schema is missing' do
    missing_root = File.join(@directory, 'missing-r5-schema')
    stub_const('FHIR::R5::Xml::SCHEMA_ROOT', missing_root)

    expect do
      FHIR::R5::Xml.validate(
        '<Patient xmlns="http://hl7.org/fhir"/>'
      )
    end.to raise_error(
      ArgumentError,
      /FHIR XML schema not found: .*missing-r5-schema\/fhir-all\.xsd/
    )
  end
end
