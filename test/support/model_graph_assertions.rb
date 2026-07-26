module ModelGraphAssertions
  def assert_model_graph_namespace(value, expected_namespace, path = 'resource')
    case value
    when FHIR::Model
      assert_same expected_namespace, FHIR.namespace_for(value.class),
                  "#{path} unexpectedly contains #{value.class}"
      model_local_names(value.class).each do |field, local_name|
        assert_model_graph_namespace(
          value.instance_variable_get("@#{local_name}"),
          expected_namespace,
          "#{path}.#{field}"
        )
      end
      value.primitive_extensions.to_h.each do |field, extension|
        assert_model_graph_namespace(
          extension,
          expected_namespace,
          "#{path}._#{field}"
        )
      end
    when Array
      value.each_with_index do |item, index|
        assert_model_graph_namespace(
          item,
          expected_namespace,
          "#{path}[#{index}]"
        )
      end
    when Hash
      value.each do |key, item|
        assert_model_graph_namespace(
          item,
          expected_namespace,
          "#{path}.#{key}"
        )
      end
    end
  end

  private

  def model_local_names(klass)
    klass::METADATA.each_with_object([]) do |(field, raw_metadata), names|
      metadata_entries = raw_metadata.is_a?(Array) ? raw_metadata : [raw_metadata]
      metadata_entries.each do |metadata|
        next unless metadata

        local_name = metadata['local_name'] || field
        names << [field, local_name] unless names.any? { |entry| entry.last == local_name }
      end
    end
  end
end
