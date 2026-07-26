module FHIR
  module R5
    FHIR_VERSION = '5.0.0'.freeze

    DEFINITIONS_SOURCE_URL = 'https://hl7.org/fhir/R5/definitions.json.zip'.freeze
    DEFINITIONS_SHA256 = 'df0d7259b4a8741d59f4971d96dd486423ecbd414c7060e9dc006ae3c3209c0c'.freeze

    EXPANSIONS_SOURCE_URL = 'https://hl7.org/fhir/R5/hl7.fhir.r5.expansions.tgz'.freeze
    EXPANSIONS_PACKAGE_NAME = 'hl7.fhir.r5.expansions'.freeze
    EXPANSIONS_PACKAGE_VERSION = '5.0.0'.freeze
    EXPANSIONS_SHA256 = 'f2fe00691fd8dfbe39193b46fb3988d8e128b6a37e1d654454de065ef675c32b'.freeze

    EXTENSIONS_SOURCE_URL =
      'https://packages2.fhir.org/packages/hl7.fhir.uv.extensions.r5/1.0.0'.freeze
    EXTENSIONS_PACKAGE_NAME = 'hl7.fhir.uv.extensions.r5'.freeze
    EXTENSIONS_PACKAGE_VERSION = '1.0.0'.freeze
    EXTENSIONS_SHA256 = 'b60edfadff29ef16a5a253083f33b1c6f83646b3cda1691745453162edbd86b9'.freeze

    SCHEMA_SOURCE_URL = 'https://hl7.org/fhir/R5/fhir-all-xsd.zip'.freeze
    SCHEMA_SHA256 = '99ec737f19b257de339148f8a7d42f78fcb193ea84e09fee916e25786a138835'.freeze

    INTEGER64_RANGE = (-9_223_372_036_854_775_808..9_223_372_036_854_775_807).freeze

    Hashable = FHIR::Hashable

    class Model < FHIR::Model
    end

    module Json
      include FHIR::Json

      def self.from_json(json)
        FHIR::Json.from_json(json, FHIR::R5)
      end
    end

    module Xml
      include FHIR::Xml

      def self.from_xml(xml)
        FHIR::Xml.from_xml(xml, FHIR::R5)
      end
    end

    def self.from_contents(contents)
      document = Nokogiri::XML(contents)
      if document.errors.empty?
        FHIR::R5::Xml.from_xml(contents)
      else
        FHIR::R5::Json.from_json(contents)
      end
    end

    def self.primitive?(datatype:, value:)
      if datatype.to_s.downcase == 'integer64'
        return false unless value.is_a?(Integer) || value.to_s.match?(/\A(0|[-+]?[1-9][0-9]*)\z/)

        return INTEGER64_RANGE.cover?(value.to_i)
      end

      FHIR.primitive?(datatype: datatype, value: value)
    end
  end
end
