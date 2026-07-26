require_relative '../test_helper'

class R5RuntimeDefinitionsAcceptanceTest < Test::Unit::TestCase
  FIXTURE_ROOT = File.expand_path('../fixtures/r5/definitions/controlled', __dir__)
  WRONG_VERSION_ROOT =
    File.expand_path('../fixtures/r5/definitions/wrong-version', __dir__)
  PROFILE_URI = 'http://example.org/fhir/StructureDefinition/controlled-patient'
  VALUE_SET_URI = 'http://example.org/fhir/ValueSet/nested'
  CODE_SYSTEM_URI = 'http://example.org/fhir/CodeSystem/nested'

  def setup
    @provider = build_provider(FIXTURE_ROOT)
  end

  def test_checked_in_resource_and_datatype_definitions_use_r5
    patient = FHIR::R5::Definitions.resource_definition('Patient')
    human_name = FHIR::R5::Definitions.type_definition('HumanName')

    assert_instance_of FHIR::R5::StructureDefinition, patient
    assert_instance_of FHIR::R5::StructureDefinition, human_name
    assert_equal 'Patient', patient.type
    assert_equal 'HumanName', human_name.type
  end

  def test_controlled_profile_lookup_and_generation_use_r5
    profile = @provider.profile(PROFILE_URI)
    profile_class = @provider.get_profile_class(PROFILE_URI)

    assert_instance_of FHIR::R5::StructureDefinition, profile
    assert_equal PROFILE_URI, profile.url
    assert_equal 'FHIR::R5::Profile::Controlledpatient::Patient',
                 profile_class.name
    assert_true profile_class < FHIR::R5::Model
  end

  def test_checked_in_search_parameters_and_expansions_are_used
    publication_status =
      'http://hl7.org/fhir/ValueSet/publication-status'
    expansion = FHIR::R5::Definitions.expansions.find do |value_set|
      value_set['url'] == publication_status
    end

    assert_include FHIR::R5::Definitions.search_parameters('Patient'), 'name'
    assert_not_nil expansion
    assert_include(
      FHIR::R5::Definitions.get_codes(publication_status)
                           .fetch('http://hl7.org/fhir/publication-status'),
      'active'
    )
  end

  def test_r5_search_parameter_expression_field_is_selected
    assert_equal ['controlled'], @provider.search_parameters('Patient')
  end

  def test_nested_expansions_inherit_systems_and_preserve_selection_flags
    codes = @provider.get_codes(VALUE_SET_URI).fetch(CODE_SYSTEM_URI)
    expansion = @provider.expansions.find do |value_set|
      value_set['url'] == VALUE_SET_URI
    end
    entries = expansion.dig('expansion', 'contains')

    assert_equal(
      %w[abstract-parent selectable-child inactive-child selectable-leaf],
      codes
    )
    assert_equal 'Selectable leaf',
                 @provider.get_display(CODE_SYSTEM_URI, 'selectable-leaf')
    assert_true find_code(entries, 'abstract-parent')['abstract']
    assert_true find_code(entries, 'inactive-child')['inactive']
    assert_equal(
      %w[selectable-child selectable-leaf],
      selectable_codes(entries).fetch(CODE_SYSTEM_URI)
    )
  end

  def test_checked_in_extension_lookup_uses_the_pinned_r5_package
    uri = 'http://fhir-registry.smarthealthit.org/StructureDefinition/capabilities'
    extension = FHIR::R5::Definitions.extension_definition(uri)

    assert_equal 'hl7.fhir.uv.extensions.r5',
                 FHIR::R5::EXTENSIONS_PACKAGE_NAME
    assert_equal '1.0.0', FHIR::R5::EXTENSIONS_PACKAGE_VERSION
    assert_instance_of FHIR::R5::StructureDefinition, extension
    assert_equal uri, extension.url
  end

  def test_wrong_version_metadata_is_rejected_by_an_isolated_provider
    assert_instance_of FHIR::R5::StructureDefinition,
                       @provider.type_definition('HumanName')
    wrong_version_provider = build_provider(WRONG_VERSION_ROOT)

    error = assert_raise(RuntimeError) do
      wrong_version_provider.type_definition('HumanName')
    end
    assert_match(/Definitions are FHIR 4\.3\.0, expected 5\.0\.0/, error.message)
    assert_not_same @provider, wrong_version_provider
    assert_not_same(
      @provider.instance_variable_get(:@definition_cache),
      wrong_version_provider.instance_variable_get(:@definition_cache)
    )
  end

  private

  def build_provider(root)
    Class.new(FHIR::Boot::DefinitionProvider).tap do |provider|
      provider.configure(
        root: root,
        namespace: FHIR::R5,
        search_parameter_field: 'expression'
      )
    end
  end

  def find_code(entries, code)
    entries.to_a.each do |entry|
      return entry if entry['code'] == code

      found = find_code(entry['contains'], code)
      return found if found
    end
    nil
  end

  def selectable_codes(entries, codes = {}, inherited_system = nil)
    entries.to_a.each do |entry|
      system = entry['system'] || inherited_system
      if system && entry['code'] &&
         entry['abstract'] != true && entry['inactive'] != true
        (codes[system] ||= []) << entry['code']
      end
      selectable_codes(entry['contains'], codes, system)
    end
    codes
  end
end
