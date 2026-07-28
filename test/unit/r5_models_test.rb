require_relative '../test_helper'

class R5ModelsTest < Test::Unit::TestCase
  ABSTRACT_RESOURCES = %w[
    Resource
    CanonicalResource
    DomainResource
    MetadataResource
  ].freeze

  REMOVED_RESOURCES = %w[
    CatalogEntry
    DeviceUseStatement
    DocumentManifest
    Media
    RequestGroup
    ResearchDefinition
    ResearchElementDefinition
  ].freeze

  R5_ONLY_RESOURCES = %w[
    ActorDefinition
    ArtifactAssessment
    BiologicallyDerivedProductDispense
    ConditionDefinition
    DeviceAssociation
    DeviceDispense
    DeviceUsage
    EncounterHistory
    FormularyItem
    GenomicStudy
    ImagingSelection
    InventoryItem
    InventoryReport
    NutritionIntake
    Permission
    RequestOrchestration
    Requirements
    SubstanceNucleicAcid
    SubstancePolymer
    SubstanceProtein
    SubstanceReferenceInformation
    SubstanceSourceMaterial
    TestPlan
    Transport
  ].freeze

  def test_r5_namespace_and_source_metadata_are_explicit
    assert_equal '5.0.0', FHIR::R5::FHIR_VERSION
    assert_equal 'https://hl7.org/fhir/R5/definitions.json.zip',
                 FHIR::R5::DEFINITIONS_SOURCE_URL
    assert_equal 'df0d7259b4a8741d59f4971d96dd486423ecbd414c7060e9dc006ae3c3209c0c',
                 FHIR::R5::DEFINITIONS_SHA256
    assert_equal 'hl7.fhir.r5.expansions', FHIR::R5::EXPANSIONS_PACKAGE_NAME
    assert_equal '5.0.0', FHIR::R5::EXPANSIONS_PACKAGE_VERSION
    assert_equal FHIR::Boot::ExpansionPackage::R5_SHA256, FHIR::R5::EXPANSIONS_SHA256
    assert_equal 'hl7.fhir.uv.extensions.r5', FHIR::R5::EXTENSIONS_PACKAGE_NAME
    assert_equal '1.0.0', FHIR::R5::EXTENSIONS_PACKAGE_VERSION
    assert_equal FHIR::Boot::ExtensionPackage::R5_SHA256, FHIR::R5::EXTENSIONS_SHA256
    assert_equal 'https://hl7.org/fhir/R5/fhir-all-xsd.zip',
                 FHIR::R5::SCHEMA_SOURCE_URL
    assert_equal '99ec737f19b257de339148f8a7d42f78fcb193ea84e09fee916e25786a138835',
                 FHIR::R5::SCHEMA_SHA256
    assert_not_equal FHIR::Patient, FHIR::R4B::Patient
    assert_not_equal FHIR::R4B::Patient, FHIR::R5::Patient
  end

  def test_generated_metadata_matches_the_r5_definition_surface
    assert_equal 21, FHIR::R5::PRIMITIVES.length
    assert_equal 48, FHIR::R5::TYPES.length
    assert_equal 162, FHIR::R5::RESOURCES.length
    assert_equal 158, (FHIR::R5::RESOURCES - ABSTRACT_RESOURCES).length
    assert_empty ABSTRACT_RESOURCES - FHIR::R5::RESOURCES
    assert_empty R5_ONLY_RESOURCES - FHIR::R5::RESOURCES
    assert_empty REMOVED_RESOURCES & FHIR::R5::RESOURCES
    assert_include FHIR::R5::PRIMITIVES.keys, 'integer64'
    assert_include FHIR::R5::TYPES, 'Availability'
    assert_include FHIR::R5::TYPES, 'ExtendedContactDetail'
    assert_include FHIR::R5::TYPES, 'MonetaryComponent'
    assert_include FHIR::R5::TYPES, 'VirtualServiceDetail'
    assert_include FHIR::R5::Patient::SEARCH_PARAMS, 'name'
  end

  def test_all_generated_metadata_types_resolve_in_r5
    primitive_types = FHIR::R5::PRIMITIVES.keys + ['xhtml']

    (FHIR::R5::TYPES + FHIR::R5::RESOURCES).each do |name|
      assert FHIR::R5.const_defined?(name, false), "Missing generated R5 class #{name}"
      klass = FHIR::R5.const_get(name)
      next unless klass.const_defined?(:METADATA, false)

      klass::METADATA.each do |field, raw_metadata|
        entries = raw_metadata.is_a?(Array) ? raw_metadata : [raw_metadata]
        entries.each do |metadata|
          type = metadata['type']
          next if primitive_types.include?(type)

          assert_nothing_raised("#{name}.#{field} references unknown R5 type #{type}") do
            FHIR::R5.const_get(type)
          end
        end
      end
    end
  end

  def test_representative_r5_only_models_can_be_instantiated
    assert_instance_of FHIR::R5::ActorDefinition, FHIR::R5::ActorDefinition.new
    assert_instance_of FHIR::R5::Transport, FHIR::R5::Transport.new
    assert_instance_of FHIR::R5::Availability, FHIR::R5::Availability.new
    REMOVED_RESOURCES.each do |name|
      assert_false FHIR::R5.const_defined?(name, false)
    end
  end

  def test_integer64_json_and_xml_round_trips_preserve_integer_values
    value = 9_223_372_036_854_775_807
    json = JSON.generate(
      'resourceType' => 'Parameters',
      'parameter' => [{ 'name' => 'large', 'valueInteger64' => value }]
    )

    resource = FHIR::R5.from_contents(json)
    assert_instance_of Integer, resource.parameter.first.valueInteger64
    assert_equal value, resource.parameter.first.valueInteger64
    assert_equal value, JSON.parse(resource.to_json).dig('parameter', 0, 'valueInteger64')

    reparsed = FHIR::R5.from_contents(resource.to_xml)
    assert_instance_of Integer, reparsed.parameter.first.valueInteger64
    assert_equal value, reparsed.parameter.first.valueInteger64
    assert_true FHIR::R5.primitive?(datatype: 'integer64', value: value)
    assert_false FHIR::R5.primitive?(datatype: 'integer64', value: value + 1)
  end

  def test_required_external_binding_fallbacks_validate_local_r5_codes
    binary = FHIR::R5::Binary.new(
      language: 'no-NO',
      contentType: 'application/fhir+json',
      data: 'dGVzdA=='
    )
    sampled_data = FHIR::R5::SampledData.new(
      origin: FHIR::R5::Quantity.new(value: 1),
      intervalUnit: 's',
      dimensions: 1
    )

    assert_empty binary.validate
    assert_empty sampled_data.validate

    binary.language = 'not_a_language'
    sampled_data.intervalUnit = 'not-a-unit'
    assert_not_empty binary.validate.fetch('language')
    assert_not_empty sampled_data.validate.fetch('intervalUnit')
  end

  def test_bundle_entries_and_contained_resources_stay_in_r5
    bundle = FHIR::R5.from_contents(
      JSON.generate(
        'resourceType' => 'Bundle',
        'type' => 'collection',
        'entry' => [
          {
            'resource' => {
              'resourceType' => 'Patient',
              'id' => 'patient',
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'id' => 'observation',
                  'status' => 'final',
                  'code' => { 'text' => 'R5 observation' }
                }
              ]
            }
          }
        ]
      )
    )

    patient = bundle.entry.first.resource
    assert_instance_of FHIR::R5::Bundle, bundle
    assert_instance_of FHIR::R5::Bundle::Entry, bundle.entry.first
    assert_instance_of FHIR::R5::Patient, patient
    assert_instance_of FHIR::R5::Observation, patient.contained.first
    assert_instance_of FHIR::R5::CodeableConcept, patient.contained.first.code
    assert_instance_of FHIR::R5::Reference, patient.to_reference
  end

  def test_generated_files_do_not_reference_r4b
    root = File.expand_path('../../lib/fhir_models/r5', __dir__)
    files = Dir[File.join(root, '**', '*.rb')]

    assert_equal 211, files.length
    files.each do |file|
      assert_not_match(/FHIR::R4B|module R4B/, File.read(file), file)
    end
  end
end
