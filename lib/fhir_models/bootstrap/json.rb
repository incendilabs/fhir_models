require 'json'

module FHIR
  module Json
    #
    #  This module includes methods to serialize or deserialize FHIR resources to and from JSON.
    #

    def to_json
      JSON.pretty_unparse(to_hash)
    end

    def self.from_json(json, namespace = FHIR)
      hash = JSON.parse(json)
      resource = nil
      begin
        resource_type = hash['resourceType']
        klass = namespace.const_get(resource_type)
        resource = klass.new(hash)
      rescue => ex
        FHIR.logger.error("Failed to deserialize JSON:\n#{ex.backtrace}")
        FHIR.logger.debug("JSON:\n#{json}")
        resource = nil
      end
      resource
    end
  end
end
