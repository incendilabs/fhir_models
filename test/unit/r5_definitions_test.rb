require_relative '../test_helper'

class R5DefinitionsTest < Test::Unit::TestCase
  RUNTIME_BUNDLES = %w[
    structures/profiles-types.json
    structures/profiles-resources.json
    structures/profiles-others.json
    structures/extension-definitions.json
    structures/search-parameters.json
    valuesets/valuesets.json
    valuesets/expansions.json
  ].freeze

  def test_runtime_artifacts_are_preprocessed_fhir_bundles
    root = File.expand_path('../../lib/fhir_models/definitions/r5', __dir__)

    assert_equal '5.0.0', version_from(File.join(root, 'version.info'))
    RUNTIME_BUNDLES.each do |relative_path|
      bundle = JSON.parse(File.read(File.join(root, relative_path)))

      assert_equal 'Bundle', bundle['resourceType'], relative_path
      assert_instance_of Array, bundle['entry'], relative_path
      assert_false contains_key?(bundle, 'fhir_comments'), relative_path
      has_narrative = bundle.fetch('entry', []).any? do |entry|
        entry.fetch('resource', {}).key?('text')
      end
      assert_false has_narrative, relative_path
    end
  end

  def test_resource_type_profile_and_extension_definitions_use_r5_models
    patient = FHIR::R5::Definitions.resource_definition('Patient')
    human_name = FHIR::R5::Definitions.type_definition('HumanName')
    profile_uri = 'http://hl7.org/fhir/StructureDefinition/shareablemeasure'
    extension_uri = 'http://hl7.org/fhir/StructureDefinition/patient-birthPlace'

    assert_instance_of FHIR::R5::StructureDefinition, patient
    assert_instance_of FHIR::R5::StructureDefinition, human_name
    assert_instance_of FHIR::R5::StructureDefinition, FHIR::R5::Definitions.profile(profile_uri)
    assert_instance_of FHIR::R5::StructureDefinition,
                       FHIR::R5::Definitions.extension_definition(extension_uri)
    assert_equal 'Patient', patient.type
    assert_equal 'HumanName', human_name.type
    assert_equal 162, FHIR::R5::Definitions.resource_definitions.length
    assert_equal 'Measure', FHIR::R5::Definitions.basetype(profile_uri)
    assert_equal 'Extension', FHIR::R5::Definitions.basetype(extension_uri)
    assert_include FHIR::R5::Definitions.profiles_for_resource('Measure').map(&:url),
                   profile_uri
  end

  def test_search_and_terminology_indexes_are_available_at_runtime
    codes = FHIR::R5::Definitions.get_codes(
      'http://hl7.org/fhir/ValueSet/publication-status'
    )

    assert_include FHIR::R5::Definitions.search_parameters('Patient'), 'name'
    assert_include codes['http://hl7.org/fhir/publication-status'], 'active'
    assert_equal 'Active', FHIR::R5::Definitions.get_display(
      'http://hl7.org/fhir/publication-status',
      'active'
    )
    assert_include FHIR::R5::Definitions.valuesets.map { |resource| resource['resourceType'] },
                   'ValueSet'
    assert_include FHIR::R5::Definitions.expansions.map { |resource| resource['resourceType'] },
                   'ValueSet'
  end

  def test_dynamic_profile_classes_use_the_r5_namespace
    profile_class = FHIR::R5::Definitions.get_profile_class(
      'http://hl7.org/fhir/StructureDefinition/shareablemeasure'
    )

    assert_equal 'FHIR::R5::Profile::Shareablemeasure::Measure', profile_class.name
    assert_true profile_class < FHIR::R5::Model
  end

  def test_r5_lookups_do_not_fall_back_to_other_versions
    assert_instance_of FHIR::StructureDefinition,
                       FHIR::Definitions.resource_definition('CatalogEntry')
    assert_instance_of FHIR::R4B::StructureDefinition,
                       FHIR::R4B::Definitions.resource_definition('CatalogEntry')
    assert_nil FHIR::R5::Definitions.resource_definition('CatalogEntry')
    assert_same FHIR::Definitions, FHIR::Patient.new.send(:fhir_definitions)
    assert_same FHIR::R4B::Definitions, FHIR::R4B::Patient.new.send(:fhir_definitions)
    assert_same FHIR::R5::Definitions, FHIR::R5::Patient.new.send(:fhir_definitions)
  end

  def test_structure_definition_validation_uses_r5_element_hierarchy
    definition = FHIR::R5::Definitions.resource_definition('Patient')
    patient = FHIR::R5::Patient.new('id' => 'r5-patient')

    assert_respond_to definition, :validates_resource?
    assert_true definition.validates_resource?(patient)
    assert_empty definition.errors
  end

  private

  def version_from(path)
    File.readlines(path).find { |line| line.start_with?('version=') }
        .to_s.split('=', 2).last.to_s.strip
  end

  def contains_key?(value, key)
    case value
    when Hash
      value.key?(key) || value.values.any? { |child| contains_key?(child, key) }
    when Array
      value.any? { |child| contains_key?(child, key) }
    else
      false
    end
  end
end
