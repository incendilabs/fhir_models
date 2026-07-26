module FHIR
  module R5
    class DataType < FHIR::R5::Model
      include FHIR::R5::Hashable
      include FHIR::R5::Json
      include FHIR::R5::Xml

      SEARCH_PARAMS = []
      METADATA = {
        'id' => {'path' => 'DataType.id', 'type' => 'string', 'min' => 0, 'max' => 1},
        'extension' => {'path' => 'DataType.extension', 'type' => 'Extension', 'min' => 0, 'max'=>Float::INFINITY}
      }

      attr_accessor :id        # 0-1 string
      attr_accessor :extension # 0-* [ Extension ]
    end
  end
end