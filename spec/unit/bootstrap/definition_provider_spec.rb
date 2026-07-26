require 'spec_helper'
require 'fileutils'
require 'tmpdir'

describe FHIR::Boot::DefinitionProvider do
  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  it 'fails clearly when version metadata is missing' do
    expect { provider.type_definition('HumanName') }.to raise_error(
      RuntimeError,
      /Definition version metadata not found/
    )
  end

  it 'fails clearly when version metadata does not match the namespace' do
    write_version('4.3.0')

    expect { provider.type_definition('HumanName') }.to raise_error(
      RuntimeError,
      /Definitions are FHIR 4\.3\.0, expected 5\.0\.0/
    )
  end

  it 'fails clearly when a required runtime artifact is missing' do
    write_version('5.0.0')

    expect { provider.type_definition('HumanName') }.to raise_error(
      RuntimeError,
      /Definition artifact not found: .*profiles-types\.json/
    )
  end

  it 'uses the configured R5 expression field for search parameters' do
    write_version('5.0.0')
    write_bundle(
      'structures/search-parameters.json',
      [
        {
          'resourceType' => 'SearchParameter',
          'base' => ['Patient'],
          'code' => 'name',
          'expression' => 'Patient.name'
        },
        {
          'resourceType' => 'SearchParameter',
          'base' => ['Patient'],
          'code' => 'legacy',
          'xpath' => 'f:Patient/f:name'
        },
        {
          'resourceType' => 'SearchParameter',
          'base' => ['Patient'],
          'code' => 'extension-only',
          'expression' => 'Patient.extension'
        }
      ]
    )

    expect(provider.search_parameters('Patient')).to eq ['name']
  end

  it 'inherits code systems through nested expansion entries' do
    write_version('5.0.0')
    write_bundle(
      'valuesets/expansions.json',
      [
        {
          'resourceType' => 'ValueSet',
          'url' => 'http://example.org/ValueSet/nested',
          'expansion' => {
            'contains' => [
              {
                'system' => 'http://example.org/CodeSystem/nested',
                'code' => 'parent',
                'contains' => [
                  {
                    'code' => 'child',
                    'contains' => [{ 'code' => 'grandchild', 'display' => 'Grandchild' }]
                  }
                ]
              }
            ]
          }
        }
      ]
    )

    definitions = provider
    codes = definitions.get_codes('http://example.org/ValueSet/nested')

    expect(codes['http://example.org/CodeSystem/nested']).to eq(
      %w[parent child grandchild]
    )
    expect(
      definitions.get_display(
        'http://example.org/CodeSystem/nested',
        'grandchild'
      )
    ).to eq 'Grandchild'
  end

  def provider
    @provider ||= Class.new(described_class).tap do |definition_provider|
      definition_provider.configure(
        root: @directory,
        namespace: FHIR::R5,
        search_parameter_field: 'expression'
      )
    end
  end

  def write_version(version)
    File.write(File.join(@directory, 'version.info'), "version=#{version}\n")
  end

  def write_bundle(relative_path, resources)
    path = File.join(@directory, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(
      path,
      JSON.generate(
        'resourceType' => 'Bundle',
        'entry' => resources.map { |resource| { 'resource' => resource } }
      )
    )
  end
end
