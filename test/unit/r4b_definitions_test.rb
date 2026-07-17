require_relative '../test_helper'

class R4BDefinitionsTest < Test::Unit::TestCase
  def test_resource_and_type_definitions_use_r4b_models
    patient = FHIR::R4B::Definitions.resource_definition('Patient')
    human_name = FHIR::R4B::Definitions.type_definition('HumanName')

    assert_instance_of FHIR::R4B::StructureDefinition, patient
    assert_instance_of FHIR::R4B::StructureDefinition, human_name
    assert_equal 'Patient', patient.type
    assert_equal 'HumanName', human_name.type
    assert_equal 143, FHIR::R4B::Definitions.resource_definitions.length
  end

  def test_r4b_only_resource_has_an_explicit_definition
    citation = FHIR::R4B::Definitions.resource_definition('Citation')

    assert_instance_of FHIR::R4B::StructureDefinition, citation
    assert_equal 'Citation', citation.name
    assert_nil FHIR::Definitions.resource_definition('Citation')
  end

  def test_profiles_and_extensions_resolve_their_base_types
    profile_uri = 'http://hl7.org/fhir/StructureDefinition/shareablemeasure'
    extension_uri = 'http://hl7.org/fhir/StructureDefinition/patient-birthPlace'

    assert_equal 'Measure', FHIR::R4B::Definitions.basetype(profile_uri)
    assert_equal 'Extension', FHIR::R4B::Definitions.basetype(extension_uri)
    assert_instance_of FHIR::R4B::StructureDefinition, FHIR::R4B::Definitions.profile(profile_uri)
    assert_instance_of FHIR::R4B::StructureDefinition, FHIR::R4B::Definitions.extension_definition(extension_uri)
    assert_include FHIR::R4B::Definitions.profiles_for_resource('Measure').map(&:url), profile_uri
  end

  def test_search_and_terminology_indexes_are_available_at_runtime
    codes = FHIR::R4B::Definitions.get_codes('http://hl7.org/fhir/ValueSet/publication-status')

    assert_include FHIR::R4B::Definitions.search_parameters('Patient'), 'name'
    assert_include codes['http://hl7.org/fhir/publication-status'], 'active'
    assert_equal 'Active', FHIR::R4B::Definitions.get_display(
      'http://hl7.org/fhir/publication-status',
      'active'
    )
  end

  def test_raw_terminology_bundles_are_available
    assert_include FHIR::R4B::Definitions.valuesets.map { |resource| resource['resourceType'] }, 'ValueSet'
    assert_include FHIR::R4B::Definitions.expansions.map { |resource| resource['resourceType'] }, 'ValueSet'
  end

  def test_dynamic_profile_classes_use_the_r4b_namespace
    profile_class = FHIR::R4B::Definitions.get_profile_class(
      'http://hl7.org/fhir/StructureDefinition/shareablemeasure'
    )

    assert_equal 'FHIR::R4B::Profile::Shareablemeasure::Measure', profile_class.name
    assert_true profile_class < FHIR::R4B::Model
  end

  def test_structure_definition_validation_uses_r4b_element_hierarchy
    definition = FHIR::R4B::Definitions.resource_definition('Patient')
    patient = FHIR::R4B::Patient.new('id' => 'r4b-patient')

    assert_respond_to definition, :validates_resource?
    assert_true definition.validates_resource?(patient)
    assert_empty definition.errors
  end

  def test_models_select_definitions_from_their_own_namespace
    assert_same FHIR::Definitions, FHIR::Patient.new.send(:fhir_definitions)
    assert_same FHIR::R4B::Definitions, FHIR::R4B::Patient.new.send(:fhir_definitions)
  end
end
