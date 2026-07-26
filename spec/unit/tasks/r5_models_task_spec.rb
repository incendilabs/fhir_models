require 'spec_helper'
require 'fileutils'
require 'rake'
require 'tmpdir'

load File.expand_path('../../../lib/fhir_models/tasks/tasks.rake', __dir__)

describe 'fhir:generate_r5_models' do
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
