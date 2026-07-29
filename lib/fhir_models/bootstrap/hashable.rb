require 'bigdecimal'
module FHIR
  module Hashable
    def to_hash
      hash = {}
      self.class::METADATA.each do |key, value|
        local_name = key
        local_name = value['local_name'] if value['local_name']
        hash[key] = instance_variable_get("@#{local_name}")
        if hash[key].respond_to?(:to_hash)
          hash[key] = hash[key].to_hash
        elsif hash[key].is_a? Array
          hash[key] = Array.new(hash[key]) # copy the array
          hash[key].each_with_index do |item, index|
            hash[key][index] = item.to_hash if item.respond_to?(:to_hash)
          end
        end
        hash[key] = serialize_primitive(hash[key], value)
      end
      hash = prune_model_hash(hash)
      merge_primitive_extensions(hash)
      hash['resourceType'] = resourceType if respond_to?(:resourceType)
      hash
    end

    def prune(thing)
      # Inspired by active-support `blank` but in our case false isn't blank ...
      # https://github.com/rails/rails/blob/v5.2.3/activesupport/lib/active_support/core_ext/object/blank.rb
      blank = ->(obj) { obj.respond_to?(:empty?) ? obj.empty? : obj.nil? }
      if thing.is_a?(Array)
        return nil if thing.empty?
        thing.map! { |i| prune(i) }
        thing.reject!(&blank)
      elsif thing.is_a?(Hash)
        return {} if thing.empty?
        thing.each do |key, value|
          thing[key] = prune(value)
        end
        thing.delete_if do |_key, value|
          blank.call(value)
        end
      end
      thing
    end

    def from_hash(hash)
      namespace = fhir_namespace
      primitives = namespace::PRIMITIVES
      primitive_arrays = extract_primitive_extensions(hash, namespace, primitives)
      # Eliminate empty values at this model level. Nested models perform the
      # same work after they have captured their own primitive extensions.
      hash = prune_input_hash(hash, primitives) unless hash.empty?
      primitive_arrays.each { |key, value| hash[key] = value }
      # clear the existing variables
      self.class::METADATA.each do |key, value|
        local_name = key
        local_name = value['local_name'] if value['local_name']
        instance_variable_set("@#{local_name}", nil)
      end
      # set the variables to the hash values
      hash.each do |key, value|
        key = key.to_s
        meta = self.class::METADATA[key]
        next if meta.nil?
        local_name = key
        local_name = meta['local_name'] if meta['local_name']
        begin
          instance_variable_set("@#{local_name}", value)
        rescue
          # TODO: this appears to be a dead code branch
          nil
        end
        # inflate the value if it isn't a primitive
        klass = primitives.key?(meta['type']) ? nil : namespace.const_get(meta['type'])
        if !klass.nil? && !value.nil?
          # handle array of objects
          if value.is_a?(Array)
            value = value.map { |child| make_child(child, klass) }
          else # handle single object
            value = make_child(value, klass)
            # if there is only one of these, but cardinality allows more, we need to wrap it in an array.
            value = [value] if value && (meta['max'] > 1)
          end
          instance_variable_set("@#{local_name}", value)
        elsif !primitives.include?(meta['type']) && meta['type'] != 'xhtml'
          FHIR.logger.error("Unhandled and unrecognized class/type: #{meta['type']}")
        elsif value.is_a?(Array)
          # array of primitives
          value = value.map { |child| convert_primitive(child, meta) }
          instance_variable_set("@#{local_name}", value)
        else
          # single primitive
          value = convert_primitive(value, meta)
          # if there is only one of these, but cardinality allows more, we need to wrap it in an array.
          value = [value] if value && (meta['max'] > 1)
          instance_variable_set("@#{local_name}", value)
        end # !klass && !nil?
      end # hash loop
      self
    end

    def extract_primitive_extensions(hash, namespace, primitives)
      @primitive_extensions = {}
      primitive_arrays = {}

      hash.each do |key, value|
        key = key.to_s
        next unless key.start_with?('_')

        field = key.delete_prefix('_')
        metadata = self.class::METADATA[field]
        next unless metadata && primitives.key?(metadata['type'])

        extension_class = namespace.const_get(:Element)
        @primitive_extensions[field] = inflate_primitive_extension(value, extension_class)
        field_value = hash[field] || hash[field.to_sym]
        if value.is_a?(Array) && metadata['max'] > 1
          primitive_arrays[field] =
            field_value.is_a?(Array) ? field_value.dup : Array.new(value.length)
        end
      end

      primitive_arrays
    end

    def prune_model_hash(hash)
      blank = ->(value) { value.respond_to?(:empty?) ? value.empty? : value.nil? }
      hash.each do |key, value|
        if value.is_a?(Array)
          preserve_placeholders = @primitive_extensions&.fetch(key, nil).is_a?(Array)
          hash[key] = value.reject(&blank) unless preserve_placeholders
        end
      end
      hash.delete_if { |_key, value| blank.call(value) }
    end

    def prune_input_hash(hash, primitives)
      blank = ->(value) { value.respond_to?(:empty?) ? value.empty? : value.nil? }
      hash.each_with_object({}) do |(raw_key, value), result|
        key = raw_key.to_s
        metadata = self.class::METADATA[key]
        if value.is_a?(Array)
          extension_key = "_#{key}"
          has_primitive_extensions =
            metadata && primitives.key?(metadata['type']) &&
            (hash.key?(extension_key) || hash.key?(extension_key.to_sym))
          value = value.reject(&blank) unless has_primitive_extensions
        end
        result[raw_key] = value unless blank.call(value)
      end
    end

    def inflate_primitive_extension(value, extension_class)
      if value.is_a?(Array)
        value.map do |entry|
          entry.nil? || entry.is_a?(extension_class) ? entry : extension_class.new(entry)
        end
      elsif value.nil? || value.is_a?(extension_class)
        value
      else
        extension_class.new(value)
      end
    end

    def merge_primitive_extensions(hash)
      return hash if @primitive_extensions.nil? || @primitive_extensions.empty?

      @primitive_extensions.each do |field, extension|
        metadata = self.class::METADATA[field]
        local_name = metadata['local_name'] || field
        if extension.is_a?(Array)
          values = instance_variable_get("@#{local_name}")
          if values.is_a?(Array) && values.any? { |value| !value.nil? }
            hash[field] = values.dup
          else
            hash.delete(field)
          end
        end
        hash["_#{field}"] = serialize_primitive_extension(extension)
      end
      hash
    end

    def serialize_primitive_extension(extension)
      if extension.is_a?(Array)
        extension.map { |entry| entry&.to_hash }
      else
        extension&.to_hash
      end
    end

    def serialize_primitive(value, metadata)
      return value unless metadata['type'] == 'integer64' && fhir_namespace == FHIR::R5

      value.is_a?(Array) ? value.map(&:to_s) : value.to_s
    end

    def make_child(child, klass)
      return child if child.is_a?(FHIR::Model)

      if child['resourceType'] && !klass::METADATA['resourceType']
        namespace = fhir_namespace
        klass = begin
          namespace.const_get(child['resourceType'])
        rescue => _exception
          # TODO: this appears to be a dead code branch
          # TODO: should this log / re-raise the exception if encountered instead of silently swallowing it?
          FHIR.logger.error("Unable to identify embedded class #{child['resourceType']}\n#{exception.backtrace}")
          nil
        end
      end
      begin
        obj = klass.new(child)
      rescue => exception
        # TODO: should this re-raise the exception if encountered instead of silently swallowing it?
        FHIR.logger.error("Unable to inflate embedded class #{klass}\n#{exception.backtrace}")
      end
      obj
    end

    def convert_primitive(value, meta)
      return value unless value.is_a?(String)

      rval = value
      if meta['type'] == 'boolean'
        rval = value.strip == 'true'
      elsif fhir_namespace::PRIMITIVES.include?(meta['type'])
        if %w[decimal integer integer64 positiveInt unsignedInt].include?(meta['type'])
          rval = BigDecimal(value.to_s)
          rval = rval.frac.zero? ? rval.to_i : rval.to_f
        end # primitive is number
      end # boolean else
      rval
    end

    def fhir_namespace
      FHIR.namespace_for(self.class)
    end

    private :prune, :make_child, :convert_primitive, :fhir_namespace,
            :extract_primitive_extensions, :inflate_primitive_extension,
            :merge_primitive_extensions, :serialize_primitive_extension,
            :serialize_primitive,
            :prune_model_hash, :prune_input_hash
  end
end
