require 'spec_helper'
require 'fileutils'
require 'rake'
require 'tmpdir'

unless Rake::Task.task_defined?('fhir:generate_r5_models')
  load File.expand_path('../../../lib/fhir_models/tasks/tasks.rake', __dir__)
end

describe 'FHIR R5 generation tasks' do
  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  it 'requires explicit definition and expansion source arguments' do
    task = Rake::Task['fhir:generate_r5_models']

    task.reenable
    expect { task.invoke }.to raise_error(
      ArgumentError,
      /Provide the R5 definitions archive path/
    )

    task.reenable
    expect { task.invoke('definitions.zip') }.to raise_error(
      ArgumentError,
      /Provide the R5 expansions package path/
    )
  end

  it 'preserves existing output when the expansion checksum is incorrect' do
    destination = destination_with_sentinel
    definitions = write_source('definitions.zip', 'not definitions')
    expansions = write_source('expansions.tgz', 'not expansions')

    expect do
      FHIR::Tasks.generate_r5_models(
        definitions_archive: definitions,
        expansions_package: expansions,
        destination: destination,
        temporary_root: @directory
      )
    end.to raise_error(ArgumentError, /Unexpected FHIR package checksum/)

    expect(directory_contents(destination)).to eq('sentinel.txt' => 'preserved')
  end

  it 'preserves existing output when the definition checksum is incorrect' do
    destination = destination_with_sentinel
    definitions = write_source('definitions.zip', 'not definitions')
    expansions = write_source('expansions.tgz', 'stubbed expansions')
    expansion_writer = instance_double(FHIR::Boot::ExpansionPackage)
    allow(FHIR::Boot::ExpansionPackage).to receive(:r5).with(expansions)
      .and_return(expansion_writer)
    allow(expansion_writer).to receive(:write) do |path|
      File.write(path, JSON.generate('resourceType' => 'Bundle', 'entry' => []))
    end

    expect do
      FHIR::Tasks.generate_r5_models(
        definitions_archive: definitions,
        expansions_package: expansions,
        destination: destination,
        temporary_root: @directory
      )
    end.to raise_error(ArgumentError, /Unexpected FHIR definitions archive checksum/)

    expect(directory_contents(destination)).to eq('sentinel.txt' => 'preserved')
  end

  it 'requires explicit extension source arguments for runtime definitions' do
    task = Rake::Task['fhir:generate_r5_definitions']

    task.reenable
    expect { task.invoke }.to raise_error(
      ArgumentError,
      /Provide the R5 definitions archive path/
    )

    task.reenable
    expect { task.invoke('definitions.zip') }.to raise_error(
      ArgumentError,
      /Provide the R5 expansions package path/
    )

    task.reenable
    expect { task.invoke('definitions.zip', 'expansions.tgz') }.to raise_error(
      ArgumentError,
      /Provide the R5 extensions package path/
    )
  end

  it 'preserves existing runtime definitions when extension validation fails' do
    destination = destination_with_sentinel
    definitions = instance_double(FHIR::Boot::JsonDefinitions)
    allow(FHIR::Tasks).to receive(:with_r5_definitions).and_yield(
      definitions,
      @directory
    )
    expect(definitions).not_to receive(:write_runtime_artifacts)
    extensions = write_source('extensions.tgz', 'not extensions')

    expect do
      FHIR::Tasks.generate_r5_definitions(
        definitions_archive: 'definitions.zip',
        expansions_package: 'expansions.tgz',
        extensions_package: extensions,
        destination: destination,
        temporary_root: @directory
      )
    end.to raise_error(ArgumentError, /Unexpected FHIR package checksum/)

    expect(directory_contents(destination)).to eq('sentinel.txt' => 'preserved')
  end

  it 'orchestrates model and runtime-definition generation with explicit destinations' do
    model_destination = File.join(@directory, 'models')
    definition_destination = File.join(@directory, 'definitions')
    allow(FHIR::Tasks).to receive(:generate_r5_models)
    allow(FHIR::Tasks).to receive(:generate_r5_definitions)
    task = Rake::Task['fhir:generate_r5']

    task.reenable
    task.invoke(
      'definitions.zip',
      'expansions.tgz',
      'extensions.tgz',
      model_destination,
      definition_destination
    )

    expect(FHIR::Tasks).to have_received(:generate_r5_models).with(
      definitions_archive: 'definitions.zip',
      expansions_package: 'expansions.tgz',
      destination: model_destination
    )
    expect(FHIR::Tasks).to have_received(:generate_r5_definitions).with(
      definitions_archive: 'definitions.zip',
      expansions_package: 'expansions.tgz',
      extensions_package: 'extensions.tgz',
      destination: definition_destination
    )
  end

  def destination_with_sentinel
    destination = File.join(@directory, 'r5')
    FileUtils.mkdir_p(destination)
    File.write(File.join(destination, 'sentinel.txt'), 'preserved')
    destination
  end

  def write_source(filename, contents)
    path = File.join(@directory, filename)
    File.binwrite(path, contents)
    path
  end

  def directory_contents(root)
    Dir[File.join(root, '**', '*')].select { |path| File.file?(path) }
      .each_with_object({}) do |path, contents|
        contents[path.delete_prefix("#{root}/")] = File.binread(path)
      end
  end
end
