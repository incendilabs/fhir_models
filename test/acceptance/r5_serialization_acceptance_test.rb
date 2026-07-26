require_relative '../test_helper'
require_relative '../support/model_graph_assertions'

class R5SerializationAcceptanceTest < Test::Unit::TestCase
  include ModelGraphAssertions

  FIXTURE_ROOT = File.expand_path('../fixtures/r5/serialization', __dir__)
  FIXTURES = {
    'unchanged-bundle' => FHIR::R5::Bundle,
    'changed-subscription' => FHIR::R5::Subscription,
    'r5-only-actor-definition' => FHIR::R5::ActorDefinition
  }.freeze

  def test_json_fixtures_round_trip_through_r5
    FIXTURES.each do |name, expected_class|
      input = JSON.parse(File.read(fixture(name, 'json')))
      resource = FHIR::R5::Json.from_json(JSON.generate(input))

      assert_instance_of expected_class, resource
      assert_r5_graph(resource)
      assert_equal input, JSON.parse(resource.to_json), name

      reparsed = FHIR::R5::Json.from_json(resource.to_json)
      assert_equal resource.to_hash, reparsed.to_hash, name
      assert_r5_graph(reparsed)
    end
  end

  def test_xml_fixtures_round_trip_through_r5
    FIXTURES.each do |name, expected_class|
      input = File.read(fixture(name, 'xml'))
      resource = FHIR::R5::Xml.from_xml(input)

      assert_instance_of expected_class, resource
      assert_r5_graph(resource)
      assert_empty FHIR::R5::Xml.validate(resource.to_xml), name

      reparsed = FHIR::R5::Xml.from_xml(resource.to_xml)
      assert_equal resource.to_hash, reparsed.to_hash, name
      assert_r5_graph(reparsed)
    end
  end

  def test_bundle_entries_contained_resources_references_and_choices_stay_in_r5
    bundle = json_resource('unchanged-bundle')
    patient = bundle.entry.first.resource
    observation = patient.contained.first

    assert_instance_of FHIR::R5::Bundle::Entry, bundle.entry.first
    assert_instance_of FHIR::R5::Patient, patient
    assert_instance_of FHIR::R5::Observation, observation
    assert_instance_of FHIR::R5::CodeableConcept, observation.code
    assert_instance_of FHIR::R5::Reference, observation.subject
    assert_instance_of FHIR::R5::Reference, patient.managingOrganization
    assert_instance_of FHIR::R5::Quantity, observation.value
    assert_r5_graph(bundle)
  end

  def test_integer64_boundaries_remain_ruby_integers
    parameters = json_resource('unchanged-bundle').entry.last.resource
    values = parameters.parameter.map(&:valueInteger64)

    assert_equal(
      [-9_223_372_036_854_775_808, 42, 9_223_372_036_854_775_807],
      values
    )
    values.each { |value| assert_instance_of Integer, value }

    xml_values = FHIR::R5::Xml.from_xml(parameters.to_xml)
                          .parameter.map(&:valueInteger64)
    assert_equal values, xml_values
    xml_values.each { |value| assert_instance_of Integer, value }
  end

  def test_primitive_extensions_survive_json_and_xml_round_trips
    input = JSON.parse(File.read(fixture('unchanged-bundle', 'json')))
    bundle = FHIR::R5::Json.from_json(JSON.generate(input))
    patient = bundle.entry.first.resource
    primitive = patient.primitive_extensions.fetch('birthDate')

    assert_instance_of FHIR::R5::Element, primitive
    assert_instance_of FHIR::R5::Extension, primitive.extension.first
    assert_equal 'estimated', primitive.extension.first.valueCode

    given_extensions = patient.name.first.primitive_extensions.fetch('given')
    assert_nil given_extensions.first
    assert_instance_of FHIR::R5::Element, given_extensions[1]
    assert_equal 'unknown', given_extensions[1].extension.first.valueCode
    assert_nil given_extensions.last

    xml_round_trip = FHIR::R5::Xml.from_xml(bundle.to_xml)
    assert_equal input, xml_round_trip.to_hash

    xml_resource = FHIR::R5::Xml.from_xml(
      File.read(fixture('unchanged-bundle', 'xml'))
    )
    json_round_trip = FHIR::R5::Json.from_json(xml_resource.to_json)
    assert_equal xml_resource.to_hash, json_round_trip.to_hash
  end

  def test_r5_only_datatype_is_inflated_inside_an_r5_only_resource
    actor = json_resource('r5-only-actor-definition')
    extension = actor.extension.first

    assert_instance_of FHIR::R5::ExtendedContactDetail,
                       extension.valueExtendedContactDetail
    assert_instance_of FHIR::R5::HumanName,
                       extension.valueExtendedContactDetail.name.first
    assert_instance_of FHIR::R5::ContactPoint,
                       extension.valueExtendedContactDetail.telecom.first
    assert_r5_graph(actor)
  end

  private

  def fixture(name, format)
    File.join(FIXTURE_ROOT, "#{name}.#{format}")
  end

  def json_resource(name)
    FHIR::R5::Json.from_json(File.read(fixture(name, 'json')))
  end

  def assert_r5_graph(value, path = 'resource')
    assert_model_graph_namespace(value, FHIR::R5, path)
  end
end
