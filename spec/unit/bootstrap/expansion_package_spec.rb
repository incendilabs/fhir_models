require 'spec_helper'
require 'digest'
require 'fileutils'
require 'rubygems/package'
require 'tmpdir'
require 'zlib'

describe FHIR::Boot::ExpansionPackage do
  let(:metadata) do
    {
      'name' => 'hl7.fhir.r5.expansions',
      'version' => '5.0.0',
      'fhirVersions' => ['5.0.0']
    }
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  it 'accepts the expected package metadata and preserves nested expansions' do
    nested = value_set(
      'http://example.org/ValueSet/nested',
      'contains' => [
        {
          'system' => 'http://example.org/system',
          'code' => 'parent',
          'contains' => [{ 'code' => 'child' }]
        }
      ]
    )
    archive = build_package('accepted.tgz', metadata, 'package/ValueSet-nested.json' => nested)

    package = package_for(archive)
    resource = package.bundle.fetch('entry').first.fetch('resource')

    expect(package.package_metadata).to include metadata
    expect(resource.dig('expansion', 'contains', 0, 'contains', 0, 'code')).to eq 'child'
  end

  it 'rejects mismatched package identity and FHIR metadata' do
    {
      'name' => 'other.package',
      'version' => '5.0.1',
      'fhirVersions' => ['4.3.0']
    }.each do |field, value|
      invalid_metadata = metadata.merge(field => value)
      archive = build_package(
        "invalid-#{field}.tgz",
        invalid_metadata,
        'package/ValueSet-test.json' => value_set('http://example.org/ValueSet/test')
      )

      expect { package_for(archive) }.to raise_error(ArgumentError, /Unexpected FHIR package/)
    end
  end

  it 'rejects a checksum mismatch before writing output' do
    archive = build_package(
      'checksum.tgz',
      metadata,
      'package/ValueSet-test.json' => value_set('http://example.org/ValueSet/test')
    )
    destination = File.join(@directory, 'expansions.json')

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

  it 'rejects malformed ValueSet JSON' do
    archive = build_package(
      'malformed.tgz',
      metadata,
      'package/ValueSet-malformed.json' => '{'
    )

    expect { package_for(archive).bundle }
      .to raise_error(ArgumentError, /Malformed JSON.*ValueSet-malformed/)
  end

  it 'rejects an unexpected resource type in a ValueSet entry' do
    archive = build_package(
      'wrong-type.tgz',
      metadata,
      'package/ValueSet-not-a-valueset.json' => JSON.generate(
        'resourceType' => 'CodeSystem',
        'url' => 'http://example.org/CodeSystem/test'
      )
    )

    expect { package_for(archive).bundle }
      .to raise_error(ArgumentError, /Unexpected resource type/)
  end

  it 'rejects duplicate ValueSet canonical URLs' do
    canonical = 'http://example.org/ValueSet/duplicate'
    archive = build_package(
      'duplicate.tgz',
      metadata,
      'package/ValueSet-one.json' => value_set(canonical),
      'package/ValueSet-two.json' => value_set(canonical)
    )

    expect { package_for(archive).bundle }
      .to raise_error(ArgumentError, /Duplicate ValueSet canonical URL/)
  end

  it 'rejects unsafe archive paths even when they would not be selected' do
    archive = build_package(
      'unsafe.tgz',
      metadata,
      '../ValueSet-unsafe.json' => value_set('http://example.org/ValueSet/unsafe')
    )

    expect { package_for(archive) }
      .to raise_error(ArgumentError, /Unsafe FHIR package path/)
  end

  it 'includes only direct package ValueSet entries' do
    included = value_set('http://example.org/ValueSet/included')
    archive = build_package(
      'selection.tgz',
      metadata,
      'package/ValueSet-included.json' => included,
      'package/example/ValueSet-example.json' => value_set('http://example.org/ValueSet/example'),
      'package/Patient-example.json' => JSON.generate('resourceType' => 'Patient')
    )

    entries = package_for(archive).bundle.fetch('entry')

    expect(entries.map { |entry| entry['fullUrl'] })
      .to eq ['http://example.org/ValueSet/included']
  end

  it 'orders output independently of archive order and writes byte-identically' do
    first = value_set('http://example.org/ValueSet/a')
    second = value_set('http://example.org/ValueSet/b')
    forward = build_package(
      'forward.tgz',
      metadata,
      'package/ValueSet-a.json' => first,
      'package/ValueSet-b.json' => second
    )
    reverse = build_package(
      'reverse.tgz',
      metadata,
      'package/ValueSet-b.json' => second,
      'package/ValueSet-a.json' => first
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
      'id' => 'hl7.fhir.r5.expansions-5.0.0',
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

  def value_set(url, expansion = {})
    JSON.generate(
      'resourceType' => 'ValueSet',
      'id' => File.basename(url),
      'url' => url,
      'version' => '5.0.0',
      'expansion' => expansion
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
