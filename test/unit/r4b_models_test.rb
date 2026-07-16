require_relative '../test_helper'

class R4BModelsTest < Test::Unit::TestCase
  PATIENT_JSON = {
    'resourceType' => 'Patient',
    'id' => 'r4b-patient',
    'name' => [
      {
        'family' => 'Example',
        'given' => ['R4B']
      }
    ],
    'contained' => [
      {
        'resourceType' => 'Observation',
        'id' => 'observation',
        'status' => 'final',
        'code' => { 'text' => 'Test observation' }
      }
    ]
  }.freeze

  def test_r4b_metadata_matches_generated_classes
    assert_equal '4.3.0', FHIR::R4B::FHIR_VERSION
    assert_equal 143, FHIR::R4B::RESOURCES.length

    (FHIR::R4B::TYPES + FHIR::R4B::RESOURCES).each do |name|
      assert FHIR::R4B.const_defined?(name, false), "Missing generated R4B class #{name}"
    end
  end

  def test_r4b_metadata_types_resolve_in_r4b_namespace
    primitive_types = FHIR::R4B::PRIMITIVES.keys + ['xhtml']
    (FHIR::R4B::TYPES + FHIR::R4B::RESOURCES).each do |name|
      klass = FHIR::R4B.const_get(name)
      klass::METADATA.each do |field, raw_metadata|
        metadata_entries = raw_metadata.is_a?(Array) ? raw_metadata : [raw_metadata]
        metadata_entries.each do |metadata|
          type = metadata['type']
          next if primitive_types.include?(type)

          assert_nothing_raised("#{name}.#{field} references unknown R4B type #{type}") do
            FHIR::R4B.const_get(type)
          end
        end
      end
    end
  end

  def test_r4b_json_inflates_only_r4b_models
    patient = FHIR::R4B.from_contents(JSON.generate(PATIENT_JSON))

    assert_instance_of FHIR::R4B::Patient, patient
    assert_instance_of FHIR::R4B::HumanName, patient.name.first
    assert_instance_of FHIR::R4B::Observation, patient.contained.first
    assert_instance_of FHIR::R4B::CodeableConcept, patient.contained.first.code
    assert_instance_of FHIR::R4B::Reference, patient.to_reference
    assert_empty patient.validate
  end

  def test_r4b_xml_round_trip_stays_in_r4b_namespace
    patient = FHIR::R4B.from_contents(JSON.generate(PATIENT_JSON))
    reparsed = FHIR::R4B.from_contents(patient.to_xml)

    assert_instance_of FHIR::R4B::Patient, reparsed
    assert_instance_of FHIR::R4B::HumanName, reparsed.name.first
    assert_instance_of FHIR::R4B::Observation, reparsed.contained.first
  end

  def test_r4_and_r4b_are_distinct_model_sets
    r4 = FHIR.from_contents(JSON.generate('resourceType' => 'Patient', 'id' => 'r4'))
    r4b = FHIR::R4B.from_contents(JSON.generate('resourceType' => 'Patient', 'id' => 'r4b'))

    assert_instance_of FHIR::Patient, r4
    assert_instance_of FHIR::R4B::Patient, r4b
    assert_not_equal r4.class, r4b.class
    assert FHIR::R4B.const_defined?(:Citation, false)
    assert_false FHIR.const_defined?(:Citation, false)
  end

  def test_r4b_only_field_is_preserved
    canonical = 'http://example.org/fhir/Group/example'
    r4b = FHIR::R4B::ActivityDefinition.new(
      'status' => 'draft',
      'subjectCanonical' => canonical
    )
    r4 = FHIR::ActivityDefinition.new(
      'status' => 'draft',
      'subjectCanonical' => canonical
    )

    assert_equal canonical, r4b.subjectCanonical
    assert_equal canonical, r4b.to_hash['subjectCanonical']
    assert_false r4.respond_to?(:subjectCanonical)
    assert_false r4.to_hash.key?('subjectCanonical')
  end

  def test_required_bindings_include_expanded_codes
    metadata = FHIR::R4B::ActivityDefinition::METADATA['status']

    assert_equal 'required', metadata.dig('binding', 'strength')
    assert_include metadata['valid_codes'].values.flatten, 'draft'
    assert_include metadata['valid_codes'].values.flatten, 'active'
  end
end
