require_relative '../test_helper'
require_relative '../support/model_graph_assertions'

class CrossVersionModelIsolationTest < Test::Unit::TestCase
  include ModelGraphAssertions

  WITNESS =
    File.expand_path('../fixtures/r5/version-isolation/subscription.json', __dir__)
  DEFINITION_ROOTS = {
    FHIR => File.expand_path('../../lib/fhir_models/definitions', __dir__),
    FHIR::R4B => File.expand_path('../../lib/fhir_models/definitions/r4b', __dir__),
    FHIR::R5 => File.expand_path('../../lib/fhir_models/definitions/r5', __dir__)
  }.freeze
  SCHEMA_ROOTS = DEFINITION_ROOTS.transform_values do |root|
    File.join(root, 'schema')
  end.freeze

  def test_r4_r4b_and_r5_model_classes_are_distinct
    assert_not_same FHIR::Patient, FHIR::R4B::Patient
    assert_not_same FHIR::Patient, FHIR::R5::Patient
    assert_not_same FHIR::R4B::Patient, FHIR::R5::Patient
    assert_not_same FHIR::Bundle::Entry, FHIR::R4B::Bundle::Entry
    assert_not_same FHIR::Bundle::Entry, FHIR::R5::Bundle::Entry
    assert_not_same FHIR::R4B::Bundle::Entry, FHIR::R5::Bundle::Entry
  end

  def test_r5_subscription_structure_is_rejected_by_r4b
    json = File.read(WITNESS)
    r5_subscription = FHIR::R5::Json.from_json(json)
    r4b_subscription = FHIR::R4B::Json.from_json(json)

    assert_instance_of FHIR::R5::Subscription, r5_subscription
    assert_instance_of FHIR::R5::Subscription::FilterBy,
                       r5_subscription.filterBy.first
    assert_equal 'http://example.org/SubscriptionTopic/encounters',
                 r5_subscription.topic
    assert_model_graph_namespace(r5_subscription, FHIR::R5)

    assert_instance_of FHIR::R4B::Subscription, r4b_subscription
    assert_false FHIR::R4B::Subscription::METADATA.key?('topic')
    assert_false FHIR::R4B::Subscription::METADATA.key?('filterBy')
    assert_include r4b_subscription.validate.keys, 'criteria'
    assert_include r4b_subscription.validate.keys, 'channel'

    xml = r5_subscription.to_xml
    assert_empty FHIR::Xml.validate(xml, SCHEMA_ROOTS.fetch(FHIR::R5))
    assert_not_empty FHIR::Xml.validate(xml, SCHEMA_ROOTS.fetch(FHIR::R4B))
  end

  def test_removed_r4b_resource_is_unavailable_in_r5
    assert_true FHIR.const_defined?(:CatalogEntry, false)
    assert_true FHIR::R4B.const_defined?(:CatalogEntry, false)
    assert_false FHIR::R5.const_defined?(:CatalogEntry, false)
    assert_instance_of FHIR::CatalogEntry, FHIR::CatalogEntry.new
    assert_instance_of FHIR::R4B::CatalogEntry, FHIR::R4B::CatalogEntry.new
    assert_nil FHIR::R5::Definitions.resource_definition('CatalogEntry')
  end

  def test_compatible_bundle_graphs_stay_in_the_selected_namespace
    json = JSON.generate(compatible_bundle)
    {
      FHIR => FHIR::Json.from_json(json),
      FHIR::R4B => FHIR::R4B::Json.from_json(json),
      FHIR::R5 => FHIR::R5::Json.from_json(json)
    }.each do |namespace, bundle|
      assert_same namespace.const_get(:Bundle), bundle.class
      assert_same namespace.const_get(:Bundle)::Entry, bundle.entry.first.class
      assert_same namespace.const_get(:Patient), bundle.entry.first.resource.class
      assert_same namespace.const_get(:Observation),
                  bundle.entry.first.resource.contained.first.class
      assert_model_graph_namespace(bundle, namespace)
    end
  end

  def test_definition_and_schema_roots_are_version_specific
    providers = {
      FHIR => FHIR::Definitions,
      FHIR::R4B => FHIR::R4B::Definitions,
      FHIR::R5 => FHIR::R5::Definitions
    }

    assert_equal 3, DEFINITION_ROOTS.values.uniq.length
    assert_equal 3, SCHEMA_ROOTS.values.uniq.length
    providers.each do |namespace, provider|
      assert_equal DEFINITION_ROOTS.fetch(namespace),
                   provider.instance_variable_get(:@root)
      assert_same namespace, provider.instance_variable_get(:@namespace)
      assert_same namespace.const_get(:StructureDefinition),
                  provider.resource_definition('Patient').class
      assert_true File.file?(File.join(SCHEMA_ROOTS.fetch(namespace), 'fhir-all.xsd'))
    end

    assert_instance_of FHIR::StructureDefinition,
                       FHIR::Definitions.resource_definition('CatalogEntry')
    assert_instance_of FHIR::R4B::StructureDefinition,
                       FHIR::R4B::Definitions.resource_definition('CatalogEntry')
    assert_nil FHIR::R5::Definitions.resource_definition('CatalogEntry')

    xml = FHIR::R5::Json.from_json(File.read(WITNESS)).to_xml
    assert_empty FHIR::R5::Xml.validate(xml)
    assert_not_empty FHIR::R4B::Xml.validate(xml)
    assert_not_empty FHIR::Xml.validate(xml)
  end

  def test_top_level_r4_and_explicit_r4b_apis_remain_unchanged
    json = JSON.generate(
      'resourceType' => 'Patient',
      'id' => 'versioned-patient',
      'managingOrganization' => {
        'reference' => 'Organization/example'
      }
    )
    r4_patient = FHIR.from_contents(json)
    r4b_patient = FHIR::R4B.from_contents(json)

    assert_instance_of FHIR::Patient, r4_patient
    assert_instance_of FHIR::Reference, r4_patient.managingOrganization
    assert_model_graph_namespace(r4_patient, FHIR)
    assert_instance_of FHIR::R4B::Patient, r4b_patient
    assert_instance_of FHIR::R4B::Reference, r4b_patient.managingOrganization
    assert_model_graph_namespace(r4b_patient, FHIR::R4B)
  end

  private

  def compatible_bundle
    {
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
                'code' => {
                  'text' => 'Namespace witness'
                },
                'subject' => {
                  'reference' => 'Patient/patient'
                }
              }
            ],
            'managingOrganization' => {
              'reference' => 'Organization/example'
            }
          }
        }
      ]
    }
  end
end
