require 'fhir_models'
require 'digest'
require 'fileutils'
require 'tmpdir'
require_relative '../r5'

module FHIR
  module Tasks
    ROOT = File.expand_path('../../..', __dir__).freeze

    module_function

    def with_r5_definitions(
      definitions_archive:,
      expansions_package:,
      temporary_root: File.join(ROOT, 'tmp')
    )
      FileUtils.mkdir_p(temporary_root)
      working = Dir.mktmpdir('r5-definitions-', temporary_root)

      begin
        expansions = File.join(working, 'expansions.json')
        FHIR::Boot::ExpansionPackage.r5(expansions_package).write(expansions)
        definitions = FHIR::Boot::JsonDefinitions.new(
          definitions_archive,
          expansions: expansions,
          entry_root: '',
          expected_checksum: FHIR::R5::DEFINITIONS_SHA256,
          search_parameter_field: 'expression'
        )
        yield definitions, working
      ensure
        FileUtils.rm_rf(working)
      end
    end

    def generate_r5_models(
      definitions_archive:,
      expansions_package:,
      destination:,
      temporary_root: File.join(ROOT, 'tmp')
    )
      with_r5_definitions(
        definitions_archive: definitions_archive,
        expansions_package: expansions_package,
        temporary_root: temporary_root
      ) do |definitions|
        destination = File.expand_path(destination, ROOT)
        parent = File.dirname(destination)
        FileUtils.mkdir_p(parent)
        staging = Dir.mktmpdir(".#{File.basename(destination)}-", parent)

        begin
          generator = FHIR::Boot::Generator.new(
            true,
            definitions: definitions,
            namespace: 'FHIR::R5',
            output_directory: staging
          )
          generator.generate_metadata
          generator.generate_types
          generator.generate_resources

          if generator.missing_required_expansion
            FHIR.logger.error(
              'MISSING REQUIRED EXPANSION(S) -- This is a fatal error in the definition files.'
            )
          elsif generator.missing_expansions
            FHIR.logger.info(
              'Missing expansions can be safely ignored due to weak binding strengths.'
            )
          end

          FileUtils.rm_rf(destination)
          FileUtils.mv(staging, destination)
          staging = nil
        ensure
          FileUtils.rm_rf(staging) if staging
        end
      end
    end

    def generate_r5_definitions(
      definitions_archive:,
      expansions_package:,
      extensions_package:,
      destination:,
      temporary_root: File.join(ROOT, 'tmp')
    )
      with_r5_definitions(
        definitions_archive: definitions_archive,
        expansions_package: expansions_package,
        temporary_root: temporary_root
      ) do |definitions, working|
        extensions = File.join(working, 'extension-definitions.json')
        FHIR::Boot::ExtensionPackage.r5(extensions_package).write(extensions)

        destination = File.expand_path(destination, ROOT)
        parent = File.dirname(destination)
        FileUtils.mkdir_p(parent)
        staging = Dir.mktmpdir(".#{File.basename(destination)}-", parent)

        begin
          definitions.write_runtime_artifacts(
            staging,
            extension_definitions: extensions
          )
          FileUtils.rm_rf(destination)
          FileUtils.mv(staging, destination)
          staging = nil
        ensure
          FileUtils.rm_rf(staging) if staging
        end
      end
    end

    def generate_r5_schema(schema_archive:, destination:)
      FHIR::Boot::SchemaArchive.new(
        schema_archive,
        entry_root: '',
        expected_checksum: FHIR::R5::SCHEMA_SHA256
      ).extract(destination)
    end
  end
end

namespace :fhir do
  desc 'console'
  task :console, [] do |_t, _args|
    sh 'bin/console'
  end

  desc 'generate fhir models'
  task :generate, [] do |_t, _args|
    # create a generator and load the definitions
    generator = FHIR::Boot::Generator.new
    # 1. generate the lists of primitive data types, complex types, and resources
    generator.generate_metadata
    # 2. generate the complex data types
    generator.generate_types
    # 3. generate the base Resources
    generator.generate_resources
    # 4. generate extensions?

    # 5. generate profiles?
    if generator.missing_required_expansion
      FHIR.logger.error 'MISSING REQUIRED EXPANSION(S) -- This is a fatal error in the definition files.'
    elsif generator.missing_expansions
      FHIR.logger.info 'Missing expansions can be safely ignored due to weak binding strengths.'
    end
  end

  desc 'generate R4B models from official JSON definition and expansion artifacts'
  task :generate_r4b, [:archive, :expansions] do |_t, args|
    archive = args[:archive] || ENV['R4B_DEFINITIONS']
    expansions = args[:expansions] || ENV['R4B_EXPANSIONS']
    raise ArgumentError, 'Provide the R4B definitions archive path' if archive.nil? || archive.empty?
    raise ArgumentError, 'Provide the R4B expansions bundle path' if expansions.nil? || expansions.empty?

    expansions_checksum = Digest::SHA256.file(expansions).hexdigest
    unless expansions_checksum == FHIR::R4B::EXPANSIONS_SHA256
      raise ArgumentError, "Unexpected R4B expansions bundle checksum: #{expansions_checksum}"
    end

    definitions = FHIR::Boot::JsonDefinitions.new(
      archive,
      expansions: expansions,
      entry_root: 'definitions.json',
      expected_checksum: FHIR::R4B::DEFINITIONS_SHA256
    )
    generator = FHIR::Boot::Generator.new(
      true,
      definitions: definitions,
      namespace: 'FHIR::R4B',
      output_directory: 'r4b'
    )
    generator.generate_metadata
    generator.generate_types
    generator.generate_resources
    definitions.write_runtime_artifacts(
      File.join('lib', 'fhir_models', 'definitions', 'r4b')
    )

    if generator.missing_required_expansion
      FHIR.logger.error 'MISSING REQUIRED EXPANSION(S) -- This is a fatal error in the definition files.'
    elsif generator.missing_expansions
      FHIR.logger.info 'Missing expansions can be safely ignored due to weak binding strengths.'
    end
  end

  desc 'generate R5 models from official JSON definitions and expansion packages'
  task :generate_r5_models, [:definitions, :expansions, :destination] do |_t, args|
    definitions = args[:definitions]
    expansions = args[:expansions]
    destination = args[:destination] || File.join('lib', 'fhir_models', 'r5')
    raise ArgumentError, 'Provide the R5 definitions archive path' if definitions.nil? || definitions.empty?
    raise ArgumentError, 'Provide the R5 expansions package path' if expansions.nil? || expansions.empty?

    FHIR::Tasks.generate_r5_models(
      definitions_archive: definitions,
      expansions_package: expansions,
      destination: destination
    )
  end

  desc 'generate R5 runtime definitions from official definition and package sources'
  task :generate_r5_definitions,
       [:definitions, :expansions, :extensions, :destination] do |_t, args|
    definitions = args[:definitions]
    expansions = args[:expansions]
    extensions = args[:extensions]
    destination = args[:destination] || File.join('lib', 'fhir_models', 'definitions', 'r5')
    raise ArgumentError, 'Provide the R5 definitions archive path' if definitions.nil? || definitions.empty?
    raise ArgumentError, 'Provide the R5 expansions package path' if expansions.nil? || expansions.empty?
    raise ArgumentError, 'Provide the R5 extensions package path' if extensions.nil? || extensions.empty?

    FHIR::Tasks.generate_r5_definitions(
      definitions_archive: definitions,
      expansions_package: expansions,
      extensions_package: extensions,
      destination: destination
    )
  end

  desc 'generate R5 models and runtime definitions from official sources'
  task :generate_r5,
       [:definitions, :expansions, :extensions, :model_destination, :definition_destination] do |_t, args|
    definitions = args[:definitions]
    expansions = args[:expansions]
    extensions = args[:extensions]
    raise ArgumentError, 'Provide the R5 definitions archive path' if definitions.nil? || definitions.empty?
    raise ArgumentError, 'Provide the R5 expansions package path' if expansions.nil? || expansions.empty?
    raise ArgumentError, 'Provide the R5 extensions package path' if extensions.nil? || extensions.empty?

    FHIR::Tasks.generate_r5_models(
      definitions_archive: definitions,
      expansions_package: expansions,
      destination: args[:model_destination] || File.join('lib', 'fhir_models', 'r5')
    )
    FHIR::Tasks.generate_r5_definitions(
      definitions_archive: definitions,
      expansions_package: expansions,
      extensions_package: extensions,
      destination: args[:definition_destination] ||
        File.join('lib', 'fhir_models', 'definitions', 'r5')
    )
  end

  desc 'generate R5 XML schemas from the official schema archive'
  task :generate_r5_schema, [:archive, :destination] do |_t, args|
    archive = args[:archive]
    destination = args[:destination] ||
      File.join('lib', 'fhir_models', 'definitions', 'r5', 'schema')
    raise ArgumentError, 'Provide the R5 schema archive path' if archive.nil? || archive.empty?

    FHIR::Tasks.generate_r5_schema(
      schema_archive: archive,
      destination: destination
    )
  end

  desc 'generate R4B XML schemas from the official schema archive'
  task :generate_r4b_schema, [:archive] do |_t, args|
    archive = args[:archive] || ENV['R4B_SCHEMA']
    raise ArgumentError, 'Provide the R4B schema archive path' if archive.nil? || archive.empty?

    destination = File.join('lib', 'fhir_models', 'definitions', 'r4b', 'schema')
    FHIR::Boot::SchemaArchive.new(
      archive,
      entry_root: 'fhir-all-xsd',
      expected_checksum: FHIR::R4B::SCHEMA_SHA256
    ).extract(destination)
  end

  desc 'preprocess definitions'
  task :preprocess, [] do |_t, _args|
    FileList['lib/fhir_models/definitions/structures/*.json'].each do |file|
      FHIR::Boot::Preprocess.pre_process_bundle(file)
    end
    FileList['lib/fhir_models/definitions/valuesets/*.json'].each do |file|
      FHIR::Boot::Preprocess.pre_process_bundle(file)
    end
    FileList['lib/fhir_models/definitions/schema/*.xsd'].each do |file|
      FHIR::Boot::Preprocess.pre_process_schema(file)
    end
    FileList['lib/fhir_models/examples/json/*.json'].each do |file|
      FHIR::Boot::Preprocess.pre_process_json_example(file)
    end
    FileList['lib/fhir_models/examples/xml/*.xml'].each do |file|
      FHIR::Boot::Preprocess.pre_process_xml_example(file)
    end
  end

  desc 'shrink implementation guide'
  task :shrinkig, [:file_path] do |_t, args|
    file_path = args[:file_path]
    files = Dir.glob(File.join(file_path, '*.json'))
    files.each do |filename|
      # Load each file
      start = File.size(filename)
      json = File.open(filename, 'r:UTF-8', &:read)
      hash = JSON.parse(json)

      # process each file
      FHIR::Boot::Preprocess.pre_process_structuredefinition(hash) if 'StructureDefinition' == hash['resourceType']
      FHIR::Boot::Preprocess.pre_process_valueset(hash) if 'ValueSet' == hash['resourceType']
      FHIR::Boot::Preprocess.pre_process_codesystem(hash) if 'CodeSystem' == hash['resourceType']
      FHIR::Boot::Preprocess.pre_process_searchparam(hash) if 'SearchParameter' == hash['resourceType']
      FHIR::Boot::Preprocess.remove_fhir_comments(hash)

      # if BlueButton, fix URLs
      if 'StructureDefinition' == hash['resourceType']
        # hash['url'].gsub!('http://hl7.org/fhir/StructureDefinition/','https://bluebutton.cms.gov/assets/ig/StructureDefinition-')
        fix_blue_button_urls(hash)
      end

      # Output the post processed file
      f = File.open(filename, 'w:UTF-8')
      f.write(JSON.pretty_unparse(hash))
      f.close
      finish = File.size(filename)
      puts "  Removed #{(start - finish) / 1024} KB" if start != finish
    end
  end

  def self.fix_blue_button_urls(hash)
    hash.each do |key, value|
      if value.is_a?(String)
        if value.start_with?('http://hl7.org/fhir/StructureDefinition/bluebutton')
          hash[key] = value.gsub('http://hl7.org/fhir/StructureDefinition/bluebutton', 'https://bluebutton.cms.gov/assets/ig/StructureDefinition-bluebutton')
        end
      elsif value.is_a?(Hash)
        fix_blue_button_urls(value)
      elsif value.is_a?(Array)
        value.each do |v|
          fix_blue_button_urls(v) if v.is_a?(Hash)
        end
      end
    end
  end

  desc 'copy artifacts from FHIR build'
  task :update, [:fhir_build_path] do |_t, args|
    fhir_build_path = args[:fhir_build_path]
    root = File.expand_path '../..', File.dirname(File.absolute_path(__FILE__))
    defns = File.join(root, 'fhir_models', 'definitions')

    # copy structure definitions and profiles...
    src = File.join(fhir_build_path, 'publish')
    dest = File.join(defns, 'structures')
    copy_artifacts(['profiles-types.json', 'profiles-resources.json', 'profiles-others.json', 'search-parameters.json', 'extension-definitions.json'], src, dest)

    # copy valuesets and expansions...
    dest = File.join(defns, 'valuesets')
    copy_artifacts(['expansions.json', 'valuesets.json', 'v2-tables.json', 'v3-codesystems.json'], src, dest)

    # copy all the XML schemas
    puts '  Copying XML schemas...'
    files = Dir.glob(File.join(src, '*.xsd'))
    files.map! { |f| File.basename(f) }
    dest = File.join(defns, 'schema')
    copy_artifacts(files, src, dest, false)

    # delete the JSON examples
    dest = File.join(root, 'fhir_models', 'examples', 'json')
    puts '  Replacing JSON examples...'
    Dir.glob(File.join(dest, '*')).each { |f| File.delete(f) unless File.directory?(f) }
    # copy the new JSON examples over
    files = Dir.glob(File.join(src, '*.json'))
    files.map! { |f| File.basename(f) }
    files.keep_if { |f| f.include?('example') && !f.include?('canonical') }
    copy_artifacts(files, src, dest, false)
    # copy the qicore examples too
    qicore = File.join(src, 'qicore')
    files = Dir.glob(File.join(qicore, '*.json'))
    files.map! { |f| File.basename(f) }
    files.keep_if { |f| f.include?('example') && !f.include?('canonical') }
    copy_artifacts(files, qicore, dest, false)

    # delete the XML examples
    dest = File.join(root, 'fhir_models', 'examples', 'xml')
    puts '  Replacing XML examples...'
    Dir.glob(File.join(dest, '*')).each { |f| File.delete(f) unless File.directory?(f) }
    # copy the new XML examples over
    files = Dir.glob(File.join(src, '*.xml'))
    files.map! { |f| File.basename(f) }
    files.keep_if { |f| f.include?('example') && !f.include?('canonical') }
    copy_artifacts(files, src, dest, false)
    # copy the qicore examples too
    files = Dir.glob(File.join(qicore, '*.xml'))
    files.map! { |f| File.basename(f) }
    files.keep_if { |f| f.include?('example') && !f.include?('canonical') }
    copy_artifacts(files, qicore, dest, false)

    # copy the version info
    copy_artifacts(['version.info'], src, defns)

    puts 'Done.'
  end

  desc 'output invariant expressions from definitions'
  task :invariants, [] do |_t, _args|
    # create a generator and load the definitions
    d = FHIR::Definitions
    defs = d.get_complex_types + d.get_resource_definitions
    invariants = {}
    defs.each do |structure_definition|
      structure_definition['snapshot']['element'].each do |element|
        next unless element['constraint']
        element['constraint'].each do |constraint|
          next unless constraint['expression']
          invariants[constraint['key']] = {
            path: element['path'],
            expression: constraint['expression'],
            human: constraint['human']
          }
        end
      end
    end
    File.open('invariants.txt', 'w:UTF-8') do |file|
      invariants.each do |key, value|
        file.write "#{key}|#{value[:path]}|#{value[:expression]}|#{value[:human]}\n"
      end
    end
    puts 'Wrote invariants into pipe-delimited file: invariants.txt'
  end

  def copy_artifacts(artifacts, src_folder, dest_folder, verbose = true)
    artifacts.each do |artifact|
      puts "  Copying #{artifact}..." if verbose
      src = File.join(src_folder, artifact)
      FileUtils.copy src, dest_folder
    end
  end
end
