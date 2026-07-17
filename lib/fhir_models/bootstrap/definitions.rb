require_relative 'definition_provider'

module FHIR
  class Definitions < FHIR::Boot::DefinitionProvider
    configure(
      root: File.expand_path('../definitions', __dir__),
      namespace: FHIR
    )
  end
end
