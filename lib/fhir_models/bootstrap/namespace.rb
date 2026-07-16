module FHIR
  def self.namespace_for(klass)
    class_name = klass.respond_to?(:name) ? klass.name.to_s : klass.class.name.to_s
    return FHIR::R4B if class_name.start_with?('FHIR::R4B::') && const_defined?(:R4B, false)

    FHIR
  end
end
