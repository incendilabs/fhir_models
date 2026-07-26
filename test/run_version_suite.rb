VERSION_SUITES = {
  'r4' => lambda {
    Dir['test/unit/**/*_test.rb'].reject do |file|
      File.basename(file).match?(/\A(?:r4b|r5)_/)
    end
  },
  'r4b' => lambda {
    %w[
      test/unit/r4b_models_test.rb
      test/unit/r4b_definitions_test.rb
      test/unit/r4b_xml_schema_validation_test.rb
    ]
  },
  'r5' => lambda {
    %w[
      test/unit/r5_models_test.rb
      test/unit/r5_definitions_test.rb
      test/unit/r5_xml_schema_validation_test.rb
      test/acceptance/r5_serialization_acceptance_test.rb
      test/acceptance/r5_runtime_definitions_acceptance_test.rb
      test/acceptance/cross_version_model_isolation_test.rb
    ]
  }
}.freeze

version = ARGV.fetch(0) do
  abort "Usage: ruby -Ilib -Itest #{__FILE__} <#{VERSION_SUITES.keys.join('|')}>"
end.downcase

suite = VERSION_SUITES[version]
abort "Unsupported FHIR version: #{version}" unless suite

ARGV.clear
suite.call.sort.each { |file| require File.expand_path(file) }
