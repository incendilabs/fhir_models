module FHIR
  module R4B
    FHIR_VERSION = '4.3.0'.freeze
    DEFINITIONS_SHA256 = 'a2793a06853c2d4540db8a72fc1c6d972528b01d113c2bb70ae2d80dc062e963'.freeze
    EXPANSIONS_SHA256 = 'fe10ca33f0de85c16b367cb57092076d7e2fbd7aff6479c8862a32bd227e3b07'.freeze

    Hashable = FHIR::Hashable

    class Model < FHIR::Model
    end

    class Definitions < FHIR::Boot::DefinitionProvider
      configure(
        root: File.expand_path('definitions/r4b', __dir__),
        namespace: FHIR::R4B
      )
    end

    module Json
      include FHIR::Json

      def self.from_json(json)
        FHIR::Json.from_json(json, FHIR::R4B)
      end
    end

    module Xml
      include FHIR::Xml

      def self.from_xml(xml)
        FHIR::Xml.from_xml(xml, FHIR::R4B)
      end
    end

    def self.from_contents(contents)
      document = Nokogiri::XML(contents)
      if document.errors.empty?
        FHIR::R4B::Xml.from_xml(contents)
      else
        FHIR::R4B::Json.from_json(contents)
      end
    end

    def self.primitive?(datatype:, value:)
      FHIR.primitive?(datatype: datatype, value: value)
    end
  end
end
