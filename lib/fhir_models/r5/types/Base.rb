module FHIR
  module R5
    class Base < FHIR::R5::Model
      include FHIR::R5::Hashable
      include FHIR::R5::Json
      include FHIR::R5::Xml

      SEARCH_PARAMS = []

    end
  end
end