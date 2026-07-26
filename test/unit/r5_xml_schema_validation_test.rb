require_relative '../test_helper'

class R5XmlSchemaValidationTest < Test::Unit::TestCase
  def test_generated_schema_contains_required_r5_files
    schema_root = FHIR::R5::Xml::SCHEMA_ROOT
    files = Dir.glob(File.join(schema_root, '*.xsd')).map { |path| File.basename(path) }

    assert_include files, 'fhir-all.xsd'
    assert_include files, 'fhir-base.xsd'
    assert_include files, 'actordefinition.xsd'
    assert_include files, 'subscription.xsd'
  end

  def test_r5_schema_accepts_an_r5_only_resource
    xml = FHIR::R5::ActorDefinition.new(
      'status' => 'draft',
      'type' => 'system'
    ).to_xml

    assert_empty FHIR::R5::Xml.validate(xml)
    assert_true FHIR::R5::Xml.valid?(xml)
    assert_not_empty FHIR::R4B::Xml.validate(xml)
  end

  def test_r5_schema_accepts_the_r5_subscription_structure
    xml = FHIR::R5::Subscription.new(
      'status' => 'requested',
      'topic' => 'http://example.org/SubscriptionTopic/example',
      'channelType' => {
        'system' => 'http://terminology.hl7.org/CodeSystem/subscription-channel-type',
        'code' => 'rest-hook'
      }
    ).to_xml

    assert_empty FHIR::R5::Xml.validate(xml)
    assert_not_empty FHIR::R4B::Xml.validate(xml)
  end

  def test_r5_schema_rejects_missing_required_elements
    xml = FHIR::R5::ActorDefinition.new.to_xml

    assert_not_empty FHIR::R5::Xml.validate(xml)
    assert_false FHIR::R5::Xml.valid?(xml)
  end

  def test_r5_schema_reports_malformed_xml
    xml = '<Patient xmlns="http://hl7.org/fhir"><id value="patient">'

    assert_not_empty FHIR::R5::Xml.validate(xml)
  end
end
