# fhir_models [![Build Status](https://api.travis-ci.org/fhir-crucible/fhir_models.svg?branch=master)](https://travis-ci.org/fhir-crucible/fhir_models)

FHIR R4, R4B, and R5 Resource models generated from FHIR StructureDefinitions.

The StructureDefinitions, XML Schemas, and examples are reused from the [HL7 FHIR build tools](https://github.com/HL7/fhir).

### Getting Started
```
$ bundle install
$ bundle exec rake fhir:console
```

### Features
- FHIR R4 Resource Models under `FHIR`
- FHIR R4B Resource Models under `FHIR::R4B`
- FHIR R5 Resource Models under `FHIR::R5`
- XML and JSON support
- Resource Validation
- Not Supported
  - Primitive Extensions
  - FHIR Comments

### Resource Basics

  Using XML...
  ```ruby
  xml = File.read('patient-example.xml')
  patient = FHIR.from_contents(xml)
  puts patient.to_xml
  ```
  Using JSON...
  ```ruby
  json = File.read('patient-example.json')
  patient = FHIR.from_contents(json)
  puts patient.to_json
  ```

  Parsing R4B content uses the explicit R4B namespace...
  ```ruby
  patient = FHIR::R4B.from_contents(json)
  puts patient.to_json
  ```

  Parsing R5 content uses the explicit R5 namespace...
  ```ruby
  patient = FHIR::R5.from_contents(json)
  puts patient.to_json
  ```

### Generating R4B Models

Generate the R4B models from the pinned FHIR 4.3.0 JSON definition archive and
ValueSet expansion bundle:

- [R4B definitions.json.zip](https://www.hl7.org/fhir/R4B/definitions.json.zip)
- [R4B expansions.json](https://www.hl7.org/fhir/R4B/expansions.json)
- [R4B fhir-all-xsd.zip](https://www.hl7.org/fhir/R4B/fhir-all-xsd.zip)

```shell
bundle exec rake "fhir:generate_r4b[path/to/r4b-definitions.json.zip,path/to/expansions.json]"
bundle exec rake "fhir:generate_r4b_schema[path/to/r4b-fhir-all-xsd.zip]"
```

The expected definition archive SHA-256 is
`a2793a06853c2d4540db8a72fc1c6d972528b01d113c2bb70ae2d80dc062e963` and the
expected expansion bundle SHA-256 is
`fe10ca33f0de85c16b367cb57092076d7e2fbd7aff6479c8862a32bd227e3b07`, and the
expected schema archive SHA-256 is
`3528d4ff44c69f2908d6159367d58b9d12fb41a48d1be3ec897947129696e6b4`.
Generated metadata, types, and resources are written to `lib/fhir_models/r4b`.
Preprocessed runtime definition bundles and version metadata are written to
`lib/fhir_models/definitions/r4b` and are checked into the repository. The
preprocessed schema set is written to
`lib/fhir_models/definitions/r4b/schema`. Downloaded source artifacts are not
checked in.

### Generating R5 Models

R5 generation uses four independently pinned official source artifacts. Keep
the downloaded inputs under the repository-local `tmp/r5-sources` directory:

| Source | Identity | SHA-256 |
| --- | --- | --- |
| [definitions.json.zip](https://hl7.org/fhir/R5/definitions.json.zip) | FHIR R5 `5.0.0` JSON definitions | `df0d7259b4a8741d59f4971d96dd486423ecbd414c7060e9dc006ae3c3209c0c` |
| [hl7.fhir.r5.expansions.tgz](https://hl7.org/fhir/R5/hl7.fhir.r5.expansions.tgz) | `hl7.fhir.r5.expansions@5.0.0` | `f2fe00691fd8dfbe39193b46fb3988d8e128b6a37e1d654454de065ef675c32b` |
| [hl7.fhir.uv.extensions.r5](https://packages2.fhir.org/packages/hl7.fhir.uv.extensions.r5/1.0.0) | `hl7.fhir.uv.extensions.r5@1.0.0` | `b60edfadff29ef16a5a253083f33b1c6f83646b3cda1691745453162edbd86b9` |
| [fhir-all-xsd.zip](https://hl7.org/fhir/R5/fhir-all-xsd.zip) | FHIR R5 `5.0.0` XML schemas | `99ec737f19b257de339148f8a7d42f78fcb193ea84e09fee916e25786a138835` |

The extension package is pinned separately from the core specification. R5
runtime generation selects applicable R5 `StructureDefinition` extension
resources from that package; it does not use profiles, examples, or extension
definitions for other FHIR versions.

Run each generation stage independently:

```shell
bundle exec rake "fhir:generate_r5_models[tmp/r5-sources/definitions.json.zip,tmp/r5-sources/hl7.fhir.r5.expansions.tgz]"
bundle exec rake "fhir:generate_r5_definitions[tmp/r5-sources/definitions.json.zip,tmp/r5-sources/hl7.fhir.r5.expansions.tgz,tmp/r5-sources/hl7.fhir.uv.extensions.r5-1.0.0.tgz]"
bundle exec rake "fhir:generate_r5_schema[tmp/r5-sources/fhir-all-xsd.zip]"
```

The aggregate task regenerates the models and runtime definitions. XML schemas
remain a separate stage:

```shell
bundle exec rake "fhir:generate_r5[tmp/r5-sources/definitions.json.zip,tmp/r5-sources/hl7.fhir.r5.expansions.tgz,tmp/r5-sources/hl7.fhir.uv.extensions.r5-1.0.0.tgz]"
bundle exec rake "fhir:generate_r5_schema[tmp/r5-sources/fhir-all-xsd.zip]"
```

Generated models are written to `lib/fhir_models/r5`. Preprocessed runtime
definitions are written to `lib/fhir_models/definitions/r5`, and preprocessed
schemas are written to `lib/fhir_models/definitions/r5/schema`. These generated
outputs are checked into the repository. Files under `tmp/r5-sources` are
downloaded inputs and are not checked in.

To verify deterministic generation without replacing the checked-in output,
generate two repository-local comparison trees:

```shell
bundle exec rake "fhir:generate_r5[tmp/r5-sources/definitions.json.zip,tmp/r5-sources/hl7.fhir.r5.expansions.tgz,tmp/r5-sources/hl7.fhir.uv.extensions.r5-1.0.0.tgz,tmp/r5-verify-a/models,tmp/r5-verify-a/definitions]"
bundle exec rake "fhir:generate_r5[tmp/r5-sources/definitions.json.zip,tmp/r5-sources/hl7.fhir.r5.expansions.tgz,tmp/r5-sources/hl7.fhir.uv.extensions.r5-1.0.0.tgz,tmp/r5-verify-b/models,tmp/r5-verify-b/definitions]"
bundle exec rake "fhir:generate_r5_schema[tmp/r5-sources/fhir-all-xsd.zip,tmp/r5-verify-a/schema]"
bundle exec rake "fhir:generate_r5_schema[tmp/r5-sources/fhir-all-xsd.zip,tmp/r5-verify-b/schema]"
diff -qr tmp/r5-verify-a tmp/r5-verify-b
```

`FHIR::Models::VERSION` is the Ruby gem release version. It is independent of
the FHIR specification version, which is explicitly exposed as
`FHIR::R5::FHIR_VERSION = '5.0.0'`.

  Creating an `Observation` by hand...
  ```ruby
  obs = FHIR::Observation.new(
    'status' => 'final',
    'code' => {
      'coding' => [{ 'system' => 'http://loinc.org', 'code' => '3141-9', 'display' => 'Weight Measured' }],
      'text' => 'Weight Measured'
    },
    'category' => {
      'coding' => [{ 'system' => 'http://hl7.org/fhir/observation-category', 'code' => 'vital-signs' }]
    },
    'subject' => { 'reference' => 'Patient/example' },
    'context' => { 'reference' => 'Encounter/example' }
  )
  obs.valueQuantity = FHIR::Quantity.new(
    'value' => 185,
    'unit' => 'lbs',
    'code' => '[lb_av]',
    'system' => 'http://unitsofmeasure.org'
  )
  ```

  ### Validation

  Using built in validation...
  ```ruby
  patient.valid? # returns true or false
  patient.validate # returns Hash of errors, empty if valid
  ```

  Using a profile or structure definition...
  ```ruby
  sd = FHIR::Definitions.resource_definition('Patient')
  sd.validates_resource?(patient) # passing in FHIR::Patient
  # Validation failed? Get the errors and warnings...
  puts sd.errors
  puts sd.warnings
  ```
# License

Copyright 2014-2019 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
