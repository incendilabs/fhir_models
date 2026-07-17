require_relative '../test_helper'

class R4BXmlSchemaValidationTest < Test::Unit::TestCase
  def test_r4b_schema_accepts_an_r4b_only_resource
    xml = FHIR::R4B::Citation.new('status' => 'draft').to_xml

    assert_empty FHIR::R4B::Xml.validate(xml)
    assert_true FHIR::R4B::Xml.valid?(xml)
  end

  def test_r4_schema_does_not_accept_an_r4b_only_resource
    xml = FHIR::R4B::Citation.new('status' => 'draft').to_xml

    assert_not_empty FHIR::Xml.validate(xml)
  end

  def test_r4b_schema_enforces_required_elements
    xml = FHIR::R4B::Citation.new.to_xml

    assert_not_empty FHIR::R4B::Xml.validate(xml)
    assert_false FHIR::R4B::Xml.valid?(xml)
  end
end
