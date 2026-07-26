# FHIR R5 Model Verification

This records Task 3 verification performed on 2026-07-26 from the
`add-r5-support` branch at:

```text
37f79cd9d4a9b3fc50a1f1ce6758ac621f972932
```

The worktree was clean at that revision. All source archives and generated
comparison outputs remained repository-local under `tmp/`.

## Environment

| Component | Version |
| --- | --- |
| Ruby | 3.4.9, revision `76cca827ab`, arm64-darwin25 |
| `fhir_models` | 4.1.0 |
| FHIR R4 | 4.0.1 |
| FHIR R4B | 4.3.0 |
| FHIR R5 | 5.0.0 |
| R5 extension package | `hl7.fhir.uv.extensions.r5#1.0.0` |
| Nokogiri | 1.19.4 |
| date_time_precision | 0.8.1 |
| bcp47 | 0.3.3 |
| mime-types | 3.7.0 |
| test-unit | 3.7.7 |
| rspec-core | 3.13.6 |
| simplecov | 0.22.0 |
| rake | 13.3.1 |
| bundler | 4.0.10 |

The repository's historical locked development bundle is not installable in
this Ruby 3.4 environment. Verification used the gems installed in
`tmp/test-gems` and the following environment on every Ruby command:

```text
RBENV_VERSION=3.4.9
PATH=/Users/kennethmyhra/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin
GEM_HOME=tmp/test-gems
GEM_PATH=tmp/test-gems:/Users/kennethmyhra/.rbenv/versions/3.4.9/lib/ruby/gems/3.4.0
RUBYOPT=-W0
```

## Pinned Sources

| Artifact | Source | SHA-256 |
| --- | --- | --- |
| R5 definitions | `https://hl7.org/fhir/R5/definitions.json.zip` | `df0d7259b4a8741d59f4971d96dd486423ecbd414c7060e9dc006ae3c3209c0c` |
| R5 expansions | `https://hl7.org/fhir/R5/hl7.fhir.r5.expansions.tgz` | `f2fe00691fd8dfbe39193b46fb3988d8e128b6a37e1d654454de065ef675c32b` |
| R5 extensions | `https://packages2.fhir.org/packages/hl7.fhir.uv.extensions.r5/1.0.0` | `b60edfadff29ef16a5a253083f33b1c6f83646b3cda1691745453162edbd86b9` |
| R5 XML schemas | `https://hl7.org/fhir/R5/fhir-all-xsd.zip` | `99ec737f19b257de339148f8a7d42f78fcb193ea84e09fee916e25786a138835` |

The downloaded files were verified at:

```text
tmp/r5-sources/definitions.json.zip
tmp/r5-sources/hl7.fhir.r5.expansions.tgz
tmp/r5-sources/hl7.fhir.uv.extensions.r5-1.0.0.tgz
tmp/r5-sources/fhir-all-xsd.zip
```

## Test Commands

Each command below was run independently. The repeated `env` prefix is the
environment listed above.

R5 model suite:

```sh
env RBENV_VERSION=3.4.9 PATH=/Users/kennethmyhra/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin GEM_HOME=tmp/test-gems GEM_PATH=tmp/test-gems:/Users/kennethmyhra/.rbenv/versions/3.4.9/lib/ruby/gems/3.4.0 RUBYOPT=-W0 \
  ruby -Ilib -Itest -e 'files = ARGV.dup; ARGV.clear; files.each { |file| require File.expand_path(file) }' \
  test/unit/r5_models_test.rb \
  test/unit/r5_definitions_test.rb \
  test/unit/r5_xml_schema_validation_test.rb \
  test/acceptance/r5_serialization_acceptance_test.rb \
  test/acceptance/r5_runtime_definitions_acceptance_test.rb \
  test/acceptance/cross_version_model_isolation_test.rb
```

R4B model suite:

```sh
env RBENV_VERSION=3.4.9 PATH=/Users/kennethmyhra/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin GEM_HOME=tmp/test-gems GEM_PATH=tmp/test-gems:/Users/kennethmyhra/.rbenv/versions/3.4.9/lib/ruby/gems/3.4.0 RUBYOPT=-W0 \
  ruby -Ilib -Itest -e 'files = ARGV.dup; ARGV.clear; files.each { |file| require File.expand_path(file) }' \
  test/unit/r4b_models_test.rb \
  test/unit/r4b_definitions_test.rb \
  test/unit/r4b_xml_schema_validation_test.rb
```

R4 model suite:

```sh
env RBENV_VERSION=3.4.9 PATH=/Users/kennethmyhra/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin GEM_HOME=tmp/test-gems GEM_PATH=tmp/test-gems:/Users/kennethmyhra/.rbenv/versions/3.4.9/lib/ruby/gems/3.4.0 RUBYOPT=-W0 \
  ruby -Ilib -Itest -e 'files = Dir["test/unit/**/*_test.rb"].reject { |file| File.basename(file).match?(/\A(?:r4b|r5)_/) }; ARGV.clear; files.each { |file| require File.expand_path(file) }'
```

Shared bootstrap and generation specs:

```sh
env RBENV_VERSION=3.4.9 PATH=/Users/kennethmyhra/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin GEM_HOME=tmp/test-gems GEM_PATH=tmp/test-gems:/Users/kennethmyhra/.rbenv/versions/3.4.9/lib/ruby/gems/3.4.0 RUBYOPT=-W0 \
  ruby -Ilib -Itest -e 'files = Dir["spec/**/*_spec.rb"].sort; ARGV.clear; require "time"; require "uri"; require "rspec/core"; helper = File.expand_path("spec/spec_helper.rb"); $LOADED_FEATURES << helper; eval(File.readlines(helper).drop(2).join, TOPLEVEL_BINDING, helper, 3); exit RSpec::Core::Runner.run(files)'
```

## Test Results

| Suite | Exit | Tests/examples | Assertions | Failures | Errors | Omissions/pending |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| R5 | 0 | 37 | 3,876 | 0 | 0 | 0 |
| R4B | 0 | 18 | 2,833 | 0 | 0 | 0 |
| R4 | 1 | 15,314 | 21,375 | 18 | 5 | 11 omissions |
| Shared RSpec | 1 | 183 | n/a | 1 | 0 | 2 pending |

## Generation Commands

All six destinations were confirmed absent before generation:

```sh
test ! -e tmp/task3d-models-first
test ! -e tmp/task3d-models-second
test ! -e tmp/task3d-definitions-first
test ! -e tmp/task3d-definitions-second
test ! -e tmp/task3d-schema-first
test ! -e tmp/task3d-schema-second
```

Models were generated twice:

```sh
for destination in tmp/task3d-models-first tmp/task3d-models-second; do
  env RBENV_VERSION=3.4.9 PATH=/Users/kennethmyhra/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin GEM_HOME=tmp/test-gems GEM_PATH=tmp/test-gems:/Users/kennethmyhra/.rbenv/versions/3.4.9/lib/ruby/gems/3.4.0 RUBYOPT=-W0 \
    ruby -Ilib -Itest -e 'require "fhir_models"; require "rake"; load "lib/fhir_models/tasks/tasks.rake"; FHIR::Tasks.generate_r5_models(definitions_archive: "tmp/r5-sources/definitions.json.zip", expansions_package: "tmp/r5-sources/hl7.fhir.r5.expansions.tgz", destination: ARGV.fetch(0))' \
    "$destination"
done
```

Runtime definitions were generated twice:

```sh
for destination in tmp/task3d-definitions-first tmp/task3d-definitions-second; do
  env RBENV_VERSION=3.4.9 PATH=/Users/kennethmyhra/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin GEM_HOME=tmp/test-gems GEM_PATH=tmp/test-gems:/Users/kennethmyhra/.rbenv/versions/3.4.9/lib/ruby/gems/3.4.0 RUBYOPT=-W0 \
    ruby -Ilib -Itest -e 'require "fhir_models"; require "rake"; load "lib/fhir_models/tasks/tasks.rake"; FHIR::Tasks.generate_r5_definitions(definitions_archive: "tmp/r5-sources/definitions.json.zip", expansions_package: "tmp/r5-sources/hl7.fhir.r5.expansions.tgz", extensions_package: "tmp/r5-sources/hl7.fhir.uv.extensions.r5-1.0.0.tgz", destination: ARGV.fetch(0))' \
    "$destination"
done
```

Schemas were generated twice:

```sh
for destination in tmp/task3d-schema-first tmp/task3d-schema-second; do
  env RBENV_VERSION=3.4.9 PATH=/Users/kennethmyhra/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin GEM_HOME=tmp/test-gems GEM_PATH=tmp/test-gems:/Users/kennethmyhra/.rbenv/versions/3.4.9/lib/ruby/gems/3.4.0 RUBYOPT=-W0 \
    ruby -Ilib -Itest -e 'require "fhir_models"; require "rake"; load "lib/fhir_models/tasks/tasks.rake"; FHIR::Tasks.generate_r5_schema(schema_archive: "tmp/r5-sources/fhir-all-xsd.zip", destination: ARGV.fetch(0))' \
    "$destination"
done
```

Comparison commands:

```sh
diff -qr tmp/task3d-models-first tmp/task3d-models-second
diff -qr tmp/task3d-models-first lib/fhir_models/r5
diff -qr tmp/task3d-definitions-first tmp/task3d-definitions-second
diff -qr tmp/task3d-definitions-first/structures lib/fhir_models/definitions/r5/structures
diff -qr tmp/task3d-definitions-first/valuesets lib/fhir_models/definitions/r5/valuesets
cmp -s tmp/task3d-definitions-first/version.info lib/fhir_models/definitions/r5/version.info
diff -qr tmp/task3d-schema-first tmp/task3d-schema-second
diff -qr tmp/task3d-schema-first lib/fhir_models/definitions/r5/schema
```

All six generation commands also exited `0`. Generation status is recorded
separately from the generator-level missing-expansion warning below.

Every comparison exited `0`. The generated file counts were:

| Artifact | Generated | Checked in |
| --- | ---: | ---: |
| Models | 211 | 211 |
| Runtime definitions | 8 | 8 |
| XML schemas | 164 | 164 |

## Existing Baseline

The R4 and shared RSpec failures were reproduced at the pre-Task-3 revision
`548a1c06` from the detached repository-local worktree
`tmp/task3d-baseline`.

At both `548a1c06` and the verified revision:

- `test/unit/profile_validation_test.rb` reports 87 tests, 171 assertions,
  18 failures, and 5 errors.
- The shared RSpec suite reports 183 examples, 1 failure, and 2 pending.

This establishes that Tasks 3A through 3C did not introduce those failures.

## Known Limitations

Failures:

- The 18 R4 failures are existing US Core profile-validation failures: 12
  Observation fixtures, 3 Organization fixtures, 1 Patient fixture, and 2
  Practitioner fixtures.
- The 5 R4 errors are existing `OpenStruct` `NameError` failures in
  `profile_validation_test.rb`.
- The shared RSpec failure is the existing R4 LOINC display lookup expectation
  in `spec/unit/bootstrap/definitions_spec.rb`.

Expected skips and pending cases:

- The R4 suite omits three slow JSON lossiness cases, six slow XML cases, and
  two extreme-decimal cases.
- The shared RSpec suite has two pending invalid-calendar-date cases for
  partial FHIR `date` and `dateTime` handling.

Generation:

- R5 model generation exits `0` and is byte-identical across runs, but reports
  `MISSING REQUIRED EXPANSION(S)` because the pinned official expansion package
  does not supply every required binding used by the StructureDefinitions,
  including `http://hl7.org/fhir/ValueSet/all-languages`.
