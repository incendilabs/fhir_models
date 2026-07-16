module FHIR
  module R4B

    PRIMITIVES = {
      'base64Binary' => {'type'=>'string', 'regex'=>'(\\s*([0-9a-zA-Z\\+/=]){4}\\s*)+'},
      'boolean' => {'type'=>'boolean', 'regex'=>'true|false'},
      'canonical' => {'type'=>'string', 'regex'=>'\\S*'},
      'code' => {'type'=>'string', 'regex'=>'[^\\s]+(\\s[^\\s]+)*'},
      'date' => {'type'=>'date', 'regex'=>'([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1]))?)?'},
      'dateTime' => {'type'=>'datetime', 'regex'=>'([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)(\\.[0-9]+)?(Z|(\\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00)))?)?)?'},
      'decimal' => {'type'=>'decimal', 'regex'=>'-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?'},
      'id' => {'type'=>'string', 'regex'=>'[A-Za-z0-9\\-\\.]{1,64}'},
      'instant' => {'type'=>'datetime', 'regex'=>'([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1])T([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)(\\.[0-9]+)?(Z|(\\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00))'},
      'integer' => {'type'=>'integer', 'regex'=>'-?([0]|([1-9][0-9]*))'},
      'markdown' => {'type'=>'string', 'regex'=>'[ \\r\\n\\t\\S]+'},
      'oid' => {'type'=>'string', 'regex'=>'urn:oid:[0-2](\\.(0|[1-9][0-9]*))+'},
      'positiveInt' => {'type'=>'string', 'regex'=>'[1-9][0-9]*'},
      'string' => {'type'=>'string', 'regex'=>'[ \\r\\n\\t\\S]+'},
      'time' => {'type'=>'time', 'regex'=>'([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)(\\.[0-9]+)?'},
      'unsignedInt' => {'type'=>'string', 'regex'=>'[0]|([1-9][0-9]*)'},
      'uri' => {'type'=>'string', 'regex'=>'\\S*'},
      'url' => {'type'=>'string', 'regex'=>'\\S*'},
      'uuid' => {'type'=>'string', 'regex'=>'urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'},
      'xhtml' => {'type'=>'string'}
    }
    TYPES = ['Element', 'BackboneElement', 'Address', 'Age', 'Annotation', 'Attachment', 'CodeableConcept', 'CodeableReference', 'Coding', 'ContactDetail', 'ContactPoint', 'Contributor', 'Count', 'DataRequirement', 'Distance', 'Dosage', 'Duration', 'ElementDefinition', 'Expression', 'Extension', 'HumanName', 'Identifier', 'MarketingStatus', 'Meta', 'Money', 'Narrative', 'ParameterDefinition', 'Period', 'Population', 'ProdCharacteristic', 'ProductShelfLife', 'Quantity', 'Range', 'Ratio', 'RatioRange', 'Reference', 'RelatedArtifact', 'SampledData', 'Signature', 'Timing', 'TriggerDefinition', 'UsageContext']
    RESOURCES = ['Resource', 'Account', 'ActivityDefinition', 'AdministrableProductDefinition', 'AdverseEvent', 'AllergyIntolerance', 'Appointment', 'AppointmentResponse', 'AuditEvent', 'Basic', 'Binary', 'BiologicallyDerivedProduct', 'BodyStructure', 'Bundle', 'CapabilityStatement', 'CarePlan', 'CareTeam', 'CatalogEntry', 'ChargeItem', 'ChargeItemDefinition', 'Citation', 'Claim', 'ClaimResponse', 'ClinicalImpression', 'ClinicalUseDefinition', 'CodeSystem', 'Communication', 'CommunicationRequest', 'CompartmentDefinition', 'Composition', 'ConceptMap', 'Condition', 'Consent', 'Contract', 'Coverage', 'CoverageEligibilityRequest', 'CoverageEligibilityResponse', 'DetectedIssue', 'Device', 'DeviceDefinition', 'DeviceMetric', 'DeviceRequest', 'DeviceUseStatement', 'DiagnosticReport', 'DocumentManifest', 'DocumentReference', 'DomainResource', 'Encounter', 'Endpoint', 'EnrollmentRequest', 'EnrollmentResponse', 'EpisodeOfCare', 'EventDefinition', 'Evidence', 'EvidenceReport', 'EvidenceVariable', 'ExampleScenario', 'ExplanationOfBenefit', 'FamilyMemberHistory', 'Flag', 'Goal', 'GraphDefinition', 'Group', 'GuidanceResponse', 'HealthcareService', 'ImagingStudy', 'Immunization', 'ImmunizationEvaluation', 'ImmunizationRecommendation', 'ImplementationGuide', 'Ingredient', 'InsurancePlan', 'Invoice', 'Library', 'Linkage', 'List', 'Location', 'ManufacturedItemDefinition', 'Measure', 'MeasureReport', 'Media', 'Medication', 'MedicationAdministration', 'MedicationDispense', 'MedicationKnowledge', 'MedicationRequest', 'MedicationStatement', 'MedicinalProductDefinition', 'MessageDefinition', 'MessageHeader', 'MolecularSequence', 'NamingSystem', 'NutritionOrder', 'NutritionProduct', 'Observation', 'ObservationDefinition', 'OperationDefinition', 'OperationOutcome', 'Organization', 'OrganizationAffiliation', 'PackagedProductDefinition', 'Parameters', 'Patient', 'PaymentNotice', 'PaymentReconciliation', 'Person', 'PlanDefinition', 'Practitioner', 'PractitionerRole', 'Procedure', 'Provenance', 'Questionnaire', 'QuestionnaireResponse', 'RegulatedAuthorization', 'RelatedPerson', 'RequestGroup', 'ResearchDefinition', 'ResearchElementDefinition', 'ResearchStudy', 'ResearchSubject', 'RiskAssessment', 'Schedule', 'SearchParameter', 'ServiceRequest', 'Slot', 'Specimen', 'SpecimenDefinition', 'StructureDefinition', 'StructureMap', 'Subscription', 'SubscriptionStatus', 'SubscriptionTopic', 'Substance', 'SubstanceDefinition', 'SupplyDelivery', 'SupplyRequest', 'Task', 'TerminologyCapabilities', 'TestReport', 'TestScript', 'ValueSet', 'VerificationResult', 'VisionPrescription']

  end
end