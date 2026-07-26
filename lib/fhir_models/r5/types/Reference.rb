module FHIR
  module R5
    class Reference < FHIR::R5::Model
      include FHIR::R5::Hashable
      include FHIR::R5::Json
      include FHIR::R5::Xml

      SEARCH_PARAMS = []
      METADATA = {
        'id' => {'path' => 'Reference.id', 'type' => 'string', 'min' => 0, 'max' => 1},
        'extension' => {'path' => 'Reference.extension', 'type' => 'Extension', 'min' => 0, 'max'=>Float::INFINITY},
        'reference' => {'path' => 'Reference.reference', 'type' => 'string', 'min' => 0, 'max' => 1},
        'type' => {'path' => 'Reference.type', 'type' => 'uri', 'min' => 0, 'max' => 1},
        'identifier' => {'path' => 'Reference.identifier', 'type' => 'Identifier', 'min' => 0, 'max' => 1},
        'display' => {'path' => 'Reference.display', 'type' => 'string', 'min' => 0, 'max' => 1}
      }

      attr_accessor :id         # 0-1 string
      attr_accessor :extension  # 0-* [ Extension ]
      attr_accessor :reference  # 0-1 string
      attr_accessor :type       # 0-1 uri
      attr_accessor :identifier # 0-1 Identifier
      attr_accessor :display    # 0-1 string
    end
  end
end