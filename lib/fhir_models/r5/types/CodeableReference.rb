module FHIR
  module R5
    class CodeableReference < FHIR::R5::Model
      include FHIR::R5::Hashable
      include FHIR::R5::Json
      include FHIR::R5::Xml

      SEARCH_PARAMS = []
      METADATA = {
        'id' => {'path' => 'CodeableReference.id', 'type' => 'string', 'min' => 0, 'max' => 1},
        'extension' => {'path' => 'CodeableReference.extension', 'type' => 'Extension', 'min' => 0, 'max'=>Float::INFINITY},
        'concept' => {'path' => 'CodeableReference.concept', 'type' => 'CodeableConcept', 'min' => 0, 'max' => 1},
        'reference' => {'path' => 'CodeableReference.reference', 'type' => 'Reference', 'min' => 0, 'max' => 1}
      }

      attr_accessor :id        # 0-1 string
      attr_accessor :extension # 0-* [ Extension ]
      attr_accessor :concept   # 0-1 CodeableConcept
      attr_accessor :reference # 0-1 Reference()
    end
  end
end