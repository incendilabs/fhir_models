require 'spec_helper'
require 'digest'
require 'rubygems/package'
require 'tmpdir'
require 'zlib'

describe FHIR::Boot::ExtensionPackage do
  let(:metadata) do
    {
      'name' => 'hl7.fhir.uv.extensions.r5',
      'version' => '1.0.0',
      'fhirVersions' => ['5.0.0']
    }
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  it 'includes only concrete R5 extension StructureDefinitions' do
    archive = build_package(
      'selection.tgz',
      metadata,
      'package/StructureDefinition-included.json' => extension_definition(
        'http://example.org/StructureDefinition/included'
      ),
      'package/StructureDefinition-profile.json' => structure_definition(
        'http://example.org/StructureDefinition/profile',
        'type' => 'Patient',
        'kind' => 'resource'
      ),
      'package/StructureDefinition-example.json' => extension_definition(
        'http://example.org/StructureDefinition/example',
        'exampleBoolean' => true
      ),
      'package/StructureDefinition-abstract.json' => extension_definition(
        'http://example.org/StructureDefinition/abstract',
        'abstract' => true
      ),
      'package/ValueSet-ignored.json' => JSON.generate('resourceType' => 'ValueSet')
    )

    entries = package_for(archive).bundle.fetch('entry')

    expect(entries.map { |entry| entry['fullUrl'] })
      .to eq ['http://example.org/StructureDefinition/included']
  end

  it 'rejects mismatched package identity, version, and FHIR versions' do
    {
      'name' => 'other.extensions',
      'version' => '1.0.1',
      'fhirVersions' => ['4.3.0']
    }.each do |field, value|
      archive = build_package(
        "invalid-#{field}.tgz",
        metadata.merge(field => value),
        'package/StructureDefinition-test.json' => extension_definition(
          'http://example.org/StructureDefinition/test'
        )
      )

      expect { package_for(archive) }.to raise_error(ArgumentError, /Unexpected FHIR package/)
    end
  end

  it 'rejects a checksum mismatch before writing output' do
    archive = build_package(
      'checksum.tgz',
      metadata,
      'package/StructureDefinition-test.json' => extension_definition(
        'http://example.org/StructureDefinition/test'
      )
    )
    destination = File.join(@directory, 'extension-definitions.json')

    expect do
      described_class.new(
        archive,
        expected_name: metadata.fetch('name'),
        expected_version: metadata.fetch('version'),
        expected_fhir_versions: metadata.fetch('fhirVersions'),
        expected_checksum: '0' * 64
      ).write(destination)
    end.to raise_error(ArgumentError, /Unexpected FHIR package checksum/)
    expect(File).not_to exist(destination)
  end

  it 'rejects unexpected resource types in StructureDefinition entries' do
    archive = build_package(
      'wrong-type.tgz',
      metadata,
      'package/StructureDefinition-invalid.json' => JSON.generate(
        'resourceType' => 'ValueSet',
        'url' => 'http://example.org/ValueSet/invalid'
      )
    )

    expect { package_for(archive).bundle }
      .to raise_error(ArgumentError, /Unexpected resource type/)
  end

  it 'rejects malformed extension shapes' do
    archive = build_package(
      'shape.tgz',
      metadata,
      'package/StructureDefinition-invalid.json' => extension_definition(
        'http://example.org/StructureDefinition/invalid',
        'derivation' => 'specialization'
      )
    )

    expect { package_for(archive).bundle }
      .to raise_error(ArgumentError, /Unexpected extension StructureDefinition shape/)
  end

  it 'rejects extension definitions for an incompatible FHIR version' do
    archive = build_package(
      'fhir-version.tgz',
      metadata,
      'package/StructureDefinition-invalid.json' => extension_definition(
        'http://example.org/StructureDefinition/invalid',
        'fhirVersion' => '4.3.0'
      )
    )

    expect { package_for(archive).bundle }
      .to raise_error(ArgumentError, /Incompatible extension fhirVersion/)
  end

  it 'rejects duplicate extension canonical URLs' do
    canonical = 'http://example.org/StructureDefinition/duplicate'
    archive = build_package(
      'duplicate.tgz',
      metadata,
      'package/StructureDefinition-one.json' => extension_definition(canonical),
      'package/StructureDefinition-two.json' => extension_definition(canonical)
    )

    expect { package_for(archive).bundle }
      .to raise_error(ArgumentError, /Duplicate extension canonical URL/)
  end

  it 'orders output independently of archive order and writes byte-identically' do
    first = extension_definition('http://example.org/StructureDefinition/a')
    second = extension_definition('http://example.org/StructureDefinition/b')
    forward = build_package(
      'forward.tgz',
      metadata,
      'package/StructureDefinition-a.json' => first,
      'package/StructureDefinition-b.json' => second
    )
    reverse = build_package(
      'reverse.tgz',
      metadata,
      'package/StructureDefinition-b.json' => second,
      'package/StructureDefinition-a.json' => first
    )
    first_output = File.join(@directory, 'first.json')
    second_output = File.join(@directory, 'second.json')
    repeated_output = File.join(@directory, 'repeated.json')

    package_for(forward).write(first_output)
    package_for(reverse).write(second_output)
    package_for(forward).write(repeated_output)

    expect(File.binread(first_output)).to eq File.binread(second_output)
    expect(File.binread(first_output)).to eq File.binread(repeated_output)
    expect(JSON.parse(File.binread(first_output))).to include(
      'resourceType' => 'Bundle',
      'id' => 'hl7.fhir.uv.extensions.r5-1.0.0-extensions',
      'type' => 'collection'
    )
  end

  def package_for(archive)
    described_class.new(
      archive,
      expected_name: metadata.fetch('name'),
      expected_version: metadata.fetch('version'),
      expected_fhir_versions: metadata.fetch('fhirVersions'),
      expected_checksum: Digest::SHA256.file(archive).hexdigest
    )
  end

  def extension_definition(url, overrides = {})
    structure_definition(
      url,
      {
        'type' => 'Extension',
        'kind' => 'complex-type',
        'derivation' => 'constraint',
        'abstract' => false,
        'fhirVersion' => '5.0.0'
      }.merge(overrides)
    )
  end

  def structure_definition(url, attributes)
    JSON.generate(
      {
        'resourceType' => 'StructureDefinition',
        'id' => File.basename(url),
        'url' => url,
        'version' => '1.0.0'
      }.merge(attributes)
    )
  end

  def build_package(filename, package_metadata, entries)
    archive = File.join(@directory, filename)
    Zlib::GzipWriter.open(archive) do |gzip|
      gzip.mtime = 0
      Gem::Package::TarWriter.new(gzip) do |tar|
        write_tar_entry(tar, 'package/package.json', JSON.generate(package_metadata))
        entries.each { |path, contents| write_tar_entry(tar, path, contents) }
      end
    end
    archive
  end

  def write_tar_entry(tar, path, contents)
    tar.add_file_simple(path, 0o644, contents.bytesize) { |io| io.write(contents) }
  end
end
