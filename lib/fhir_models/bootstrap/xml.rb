require 'nokogiri'
module FHIR
  module Xml
    extend FHIR::Deprecate
    #
    #  This module includes methods to serialize or deserialize FHIR resources to and from XML.
    #

    def to_xml
      hash = to_hash
      hash.delete('resourceType')
      doc = Nokogiri::XML::Document.new
      doc.encoding = 'utf-8'
      doc.root = hash_to_xml_node(resourceType, hash, doc, self.class)
      doc.root.default_namespace = 'http://hl7.org/fhir'
      doc.to_xml
    end

    # Hash keys are ordered in Ruby 1.9 and later, so we can rely on their order
    # to be the correct order for the XML serialization.
    def hash_to_xml_node(name, hash, doc, klass = nil)
      resources = fhir_namespace::RESOURCES
      node = Nokogiri::XML::Node.new(name, doc)
      metadata = klass && klass.const_defined?(:METADATA, false) ? klass::METADATA : {}

      # if hash contains resourceType
      # create a child node with the name==resourceType
      # fill that, and place the child under the above `node`
      if hash['resourceType'] &&
         hash['resourceType'].is_a?(String) &&
         name != 'instance' &&
         resources.include?(klass.to_s.split('::').last)
        child_name = hash['resourceType']
        hash.delete('resourceType')
        child = hash_to_xml_node(child_name, hash, doc, klass)
        node.add_child(child)
        return node
      end

      hash.each do |key, value|
        next if key.start_with?('_')

        next if %w[extension modifierExtension].include?(name) && key == 'url'
        next if key == 'id' && !resources.include?(name)
        primitive_extension = hash["_#{key}"]
        field_metadata = metadata[key]
        if value.is_a?(Hash)
          child_class = serialization_child_class(value, field_metadata)
          node.add_child(hash_to_xml_node(key, value, doc, child_class))
        elsif value.is_a?(Array)
          length = primitive_extension.is_a?(Array) ?
            [value.length, primitive_extension.length].max : value.length
          length.times do |index|
            v = value[index]
            if v.is_a?(Hash)
              child_class = serialization_child_class(v, field_metadata)
              node.add_child(hash_to_xml_node(key, v, doc, child_class))
            else
              extension = primitive_extension[index] if primitive_extension.is_a?(Array)
              child = primitive_xml_node(key, v, extension, doc)
              node.add_child(child) if child
            end
          end
        else
          if name == 'text' && key == 'div'
            child = Nokogiri::XML::Node.new(key, doc)
            child.set_attribute('xmlns', 'http://www.w3.org/1999/xhtml')
            html = value.strip
            if html.start_with?('<div') && html.end_with?('</div>')
              html = html[html.index('>') + 1..-7]
            end
            child.inner_html = html
          else
            child = primitive_xml_node(key, value, primitive_extension, doc)
          end
          node.add_child(child) if child
        end
      end
      hash.each do |key, extension|
        next unless key.start_with?('_')
        next if hash.key?(key.delete_prefix('_'))

        field = key.delete_prefix('_')
        extensions = extension.is_a?(Array) ? extension : [extension]
        extensions.each do |entry|
          child = primitive_xml_node(field, nil, entry, doc)
          node.add_child(child) if child
        end
      end
      node.set_attribute('url', hash['url']) if %w[extension modifierExtension].include?(name)
      node.set_attribute('id', hash['id']) if hash['id'] && !resources.include?(name)
      node
    end

    def primitive_xml_node(name, value, extension, doc)
      return nil if value.nil? && extension.nil?

      child = Nokogiri::XML::Node.new(name, doc)
      child.set_attribute('value', value) unless value.nil?
      return child unless extension

      child.set_attribute('id', extension['id']) if extension['id']
      Array(extension['extension']).each do |item|
        extension_class = fhir_namespace.const_get(:Extension)
        child.add_child(hash_to_xml_node('extension', item, doc, extension_class))
      end
      child
    end

    def serialization_child_class(value, metadata)
      return nil unless metadata

      type = metadata.is_a?(Array) ? metadata.first['type'] : metadata['type']
      if type == 'Resource' &&
         value['resourceType'] &&
         fhir_namespace::RESOURCES.include?(value['resourceType'])
        return fhir_namespace.const_get(value['resourceType'])
      end
      return nil if type == 'Resource' || type == 'xhtml'

      type.split('::').inject(fhir_namespace) { |context, name| context.const_get(name) }
    rescue NameError
      nil
    end

    def self.from_xml(xml, namespace = FHIR)
      doc = Nokogiri::XML(xml)
      doc.root.add_namespace_definition('f', 'http://hl7.org/fhir')
      doc.root.add_namespace_definition('x', 'http://www.w3.org/1999/xhtml')

      resource = nil
      begin
        resource_type = doc.root.name
        klass = namespace.const_get(resource_type)
        hash = xml_node_to_hash(doc.root, namespace, klass)
        resource = klass.new(hash)
      rescue => ex
        FHIR.logger.error("Failed to deserialize XML:\n#{ex.backtrace}")
        FHIR.logger.debug("XML:\n#{xml}")
        resource = nil
      end
      resource
    end

    def self.xml_node_to_hash(node, namespace = FHIR, klass = nil)
      hash = {}
      metadata = klass && klass.const_defined?(:METADATA, false) ? klass::METADATA : {}
      node.children.each do |child|
        next if [Nokogiri::XML::Text, Nokogiri::XML::Comment].include?(child.class)

        key = child.name
        if node.name == 'text' && key == 'div'
          hash[key] = child.to_xml
        else
          field_metadata = metadata[key]
          if primitive_xml_field?(field_metadata, namespace)
            append_primitive_xml_value(hash, key, child, field_metadata, namespace)
            next
          end

          value = child.get_attribute('value')
          if value.nil? && !child.children.empty?
            child_class = xml_child_class(child, field_metadata, namespace)
            value = xml_node_to_hash(child, namespace, child_class)
          end

          if hash[key]
            hash[key] = [hash[key]] unless hash[key].is_a?(Array)
            hash[key] << value
          else
            hash[key] = value
          end
        end
      end
      hash['url'] = node.get_attribute('url') if %w[extension modifierExtension].include?(node.name)
      hash['id'] = node.get_attribute('id') if node.get_attribute('id') # Testscript fixture ids (applies to any BackboneElement)
      hash['resourceType'] = node.name if namespace::RESOURCES.include?(node.name)

      # If this hash contains nothing but an embedded resource, we should return that
      # embedded resource without the wrapper
      if hash.keys.length == 1 &&
         namespace::RESOURCES.include?(hash.keys.first) &&
         hash.values.first.is_a?(Hash) &&
         hash.values.first['resourceType'] == hash.keys.first
        hash.values.first
      else
        hash
      end
    end

    def self.primitive_xml_field?(metadata, namespace)
      metadata && namespace::PRIMITIVES.key?(metadata['type'])
    end

    def self.append_primitive_xml_value(hash, key, node, metadata, namespace)
      value = node.get_attribute('value')
      extension = primitive_extension_from_xml(node, namespace)

      if metadata['max'] > 1
        values = (hash[key] ||= [])
        index = values.length
        values << value
        extension_key = "_#{key}"
        if extension
          extensions = (hash[extension_key] ||= Array.new(index))
          extensions << extension
        elsif hash.key?(extension_key)
          hash[extension_key] << nil
        end
      else
        hash[key] = value unless value.nil?
        hash["_#{key}"] = extension if extension
      end
    end

    def self.primitive_extension_from_xml(node, namespace)
      extension = {}
      extension['id'] = node.get_attribute('id') if node.get_attribute('id')
      children = node.element_children.select { |child| child.name == 'extension' }
      unless children.empty?
        extension_class = namespace.const_get(:Extension)
        extension['extension'] = children.map do |child|
          xml_node_to_hash(child, namespace, extension_class)
        end
      end
      extension.empty? ? nil : extension
    end

    def self.xml_child_class(node, metadata, namespace)
      return namespace.const_get(node.name) if namespace::RESOURCES.include?(node.name)
      return nil unless metadata

      type = metadata['type']
      return nil if type == 'Resource' || type == 'xhtml'

      type.split('::').inject(namespace) { |context, name| context.const_get(name) }
    rescue NameError
      nil
    end

    def self.valid?(xml)
      validate(xml).empty?
    end
    deprecate :is_valid?, :valid?

    def self.validate(xml, schema_root = nil)
      schema_root ||= File.expand_path '../definitions/schema', File.dirname(File.absolute_path(__FILE__))
      schema = File.join(schema_root, 'fhir-all.xsd')
      raise ArgumentError, "FHIR XML schema not found: #{schema}" unless File.file?(schema)

      xsd = Nokogiri::XML::Schema(File.new(schema))
      document = Nokogiri::XML(xml)
      document.errors + xsd.validate(document)
    end

    private :hash_to_xml_node, :primitive_xml_node, :serialization_child_class
    private_class_method :xml_node_to_hash, :primitive_xml_field?,
                         :append_primitive_xml_value, :primitive_extension_from_xml,
                         :xml_child_class
  end
end
