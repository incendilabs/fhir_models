module FHIR
  module R5
    class CodeableConcept < FHIR::R5::Model
      include FHIR::R5::Hashable
      include FHIR::R5::Json
      include FHIR::R5::Xml

      SEARCH_PARAMS = []
      METADATA = {
        'id' => {'path' => 'CodeableConcept.id', 'type' => 'string', 'min' => 0, 'max' => 1},
        'extension' => {'path' => 'CodeableConcept.extension', 'type' => 'Extension', 'min' => 0, 'max'=>Float::INFINITY},
        'coding' => {'path' => 'CodeableConcept.coding', 'type' => 'Coding', 'min' => 0, 'max'=>Float::INFINITY},
        'text' => {'path' => 'CodeableConcept.text', 'type' => 'string', 'min' => 0, 'max' => 1}
      }

      attr_accessor :id        # 0-1 string
      attr_accessor :extension # 0-* [ Extension ]
      attr_accessor :coding    # 0-* [ Coding ]
      attr_accessor :text      # 0-1 string
    end
  end
end