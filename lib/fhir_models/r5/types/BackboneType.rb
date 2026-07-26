module FHIR
  module R5
    class BackboneType < FHIR::R5::Model
      include FHIR::R5::Hashable
      include FHIR::R5::Json
      include FHIR::R5::Xml

      SEARCH_PARAMS = []
      METADATA = {
        'id' => {'path' => 'BackboneType.id', 'type' => 'string', 'min' => 0, 'max' => 1},
        'extension' => {'path' => 'BackboneType.extension', 'type' => 'Extension', 'min' => 0, 'max'=>Float::INFINITY},
        'modifierExtension' => {'path' => 'BackboneType.modifierExtension', 'type' => 'Extension', 'min' => 0, 'max'=>Float::INFINITY}
      }

      attr_accessor :id                # 0-1 string
      attr_accessor :extension         # 0-* [ Extension ]
      attr_accessor :modifierExtension # 0-* [ Extension ]
    end
  end
end