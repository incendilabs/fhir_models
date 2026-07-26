module FHIR
  module R5
    class Period < FHIR::R5::Model
      include FHIR::R5::Hashable
      include FHIR::R5::Json
      include FHIR::R5::Xml

      SEARCH_PARAMS = []
      METADATA = {
        'id' => {'path' => 'Period.id', 'type' => 'string', 'min' => 0, 'max' => 1},
        'extension' => {'path' => 'Period.extension', 'type' => 'Extension', 'min' => 0, 'max'=>Float::INFINITY},
        'start' => {'path' => 'Period.start', 'type' => 'dateTime', 'min' => 0, 'max' => 1},
        'end' => {'path' => 'Period.end', 'type' => 'dateTime', 'min' => 0, 'max' => 1}
      }

      attr_accessor :id        # 0-1 string
      attr_accessor :extension # 0-* [ Extension ]
      attr_accessor :start     # 0-1 dateTime
      attr_accessor :end       # 0-1 dateTime
    end
  end
end