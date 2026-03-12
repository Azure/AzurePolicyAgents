class PropertyValueTestConfig {
  [ValidateNotNullOrEmpty()][string]$testName
  [ValidateNotNullOrEmpty()][string]$resourceId
  [ValidateNotNullOrEmpty()][string]$token
  [ValidateNotNullOrEmpty()][string]$property
  [ValidateNotNullOrEmpty()][string]$value
  [ValidateSet('string', 'number', 'boolean')][string]$valueType
  [ValidateSet('equals', 'notEquals', 'greater', 'less', 'greaterequal', 'lessequal', 'match', 'notmatch', 'like', 'notlike')][string]$condition
  [string]$apiVersion
  [string]$resourceType

  # common constructor
  PropertyValueTestConfig([string]$testName, [string]$token, [string]$resourceId, [string]$valueType, [string]$property, [string]$condition, [string]$value) {
    $this.testName = $testName
    $this.resourceId = $resourceId
    $this.token = $token
    $this.property = $property
    $this.value = $value
    $this.valueType = $valueType
    $this.condition = $condition
  }

  # Default constructor
  PropertyValueTestConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  PropertyValueTestConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}
class PropertyCountTestConfig {
  [ValidateNotNullOrEmpty()][string]$testName
  [ValidateNotNullOrEmpty()][string]$resourceId
  [ValidateNotNullOrEmpty()][string]$token
  [ValidateNotNullOrEmpty()][string[]]$property
  [ValidateNotNullOrEmpty()][int]$count
  [ValidateSet('and', 'or', 'concat')][string]$operator
  [ValidateSet('equals', 'notEquals', 'greater', 'less', 'greaterequal', 'lessequal')][string]$condition
  [string]$apiVersion
  [string]$resourceType

  # Common constructor for multiple properties and condition
  PropertyCountTestConfig([string]$testName, [string]$token, [string]$resourceId, [string]$operator, [string[]]$property, [string]$condition, [string]$count) {
    $this.testName = $testName
    $this.token = $token
    $this.resourceId = $resourceId
    $this.property = $property
    $this.count = $count
    $this.condition = $condition
    $this.operator = $operator
  }

  # Common constructor for single property and condition
  PropertyCountTestConfig([string]$testName, [string]$token, [string]$resourceId, [string[]]$property, [string]$condition, [string]$count) {
    $this.testName = $testName
    $this.token = $token
    $this.resourceId = $resourceId
    $this.property = $property
    $this.count = $count
    $this.condition = $condition
  }
  # Default constructor
  PropertyCountTestConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  PropertyCountTestConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

class PolicyStateTestConfig {
  [ValidateNotNullOrEmpty()][string]$testName
  [ValidateNotNullOrEmpty()][string]$resourceId
  [ValidateNotNullOrEmpty()][string]$policyAssignmentId
  [ValidateNotNullOrEmpty()][string]$token
  [ValidateSet('Compliant', 'NonCompliant')][string]$requiredComplianceState
  [string]$policyDefinitionReferenceId

  # Common constructor for resource Id and policyAssignmentId
  PolicyStateTestConfig([string]$testName, [string]$token, [string]$resourceId, [string]$policyAssignmentId, [string]$requiredComplianceState) {
    $this.testName = $testName
    $this.resourceId = $resourceId
    $this.policyAssignmentId = $policyAssignmentId
    $this.token = $token
    $this.requiredComplianceState = $requiredComplianceState
  }

  # Default constructor
  PolicyStateTestConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  PolicyStateTestConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

class ResourceExistenceTestConfig {
  [ValidateNotNullOrEmpty()][string]$testName
  [ValidateNotNullOrEmpty()][string]$resourceId
  [ValidateNotNullOrEmpty()][string]$token
  [ValidateSet('exists', 'notExists')][string]$condition
  [string]$apiVersion

  # constructors
  ResourceExistenceTestConfig([string]$testName, [string]$token, [string]$resourceId, [string]$condition) {
    $this.testName = $testName
    $this.resourceId = $resourceId
    $this.token = $token
    $this.condition = $condition
  }

  ResourceExistenceTestConfig([string]$testName, [string]$token, [string]$resourceId, [string]$condition, [string]$apiVersion) {
    $this.testName = $testName
    $this.resourceId = $resourceId
    $this.token = $token
    $this.condition = $condition
    $this.apiVersion = $apiVersion
  }

  # Default constructor
  ResourceExistenceTestConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  ResourceExistenceTestConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

class PolicyViolationInfo {
  [ValidateNotNullOrEmpty()][string]$policyAssignmentId
  [string]$policyDefinitionReferenceId

  # constructors
  PolicyViolationInfo([string]$policyAssignmentId) {
    $this.policyAssignmentId = $policyAssignmentId
  }

  PolicyViolationInfo([string]$policyAssignmentId, [string]$policyDefinitionReferenceId) {
    $this.policyAssignmentId = $policyAssignmentId
    $this.policyDefinitionReferenceId = $policyDefinitionReferenceId
  }

  PolicyViolationInfo([string]$policyAssignmentId, [string]$policyDefinitionReferenceId, [string]$resourceReference, [string]$policyEffect) {
    $this.policyAssignmentId = $policyAssignmentId
    $this.policyDefinitionReferenceId = $policyDefinitionReferenceId
    $this.resourceReference = $resourceReference
    $this.policyEffect = $policyEffect
  }
  # Default constructor
  PolicyViolationInfo() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  PolicyViolationInfo([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

# This class is used to represent a policy violation that is returned from the Azure Policy restriction API. It's inherited from PolicyViolationInfo since it shares some common properties.
class PolicyRestrictionViolationInfo: PolicyViolationInfo {
  [ValidateNotNullOrEmpty()][string]$resourceReference
  [ValidateNotNullOrEmpty()][string]$policyEffect

  policyRestrictionViolationInfo([string]$policyAssignmentId, [string]$policyDefinitionReferenceId, [string]$resourceReference, [string]$policyEffect) {
    $this.policyAssignmentId = $policyAssignmentId
    $this.policyDefinitionReferenceId = $policyDefinitionReferenceId
    $this.resourceReference = $resourceReference
    $this.policyEffect = $policyEffect
  }

  policyRestrictionViolationInfo([string]$policyAssignmentId, [string]$resourceReference, [string]$policyEffect) {
    $this.policyAssignmentId = $policyAssignmentId
    $this.resourceReference = $resourceReference
    $this.policyEffect = $policyEffect
  }

  # Default constructor
  policyRestrictionViolationInfo() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  policyRestrictionViolationInfo([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

class WhatIfDeploymentTestConfig {
  [ValidateNotNullOrEmpty()][string]$testName
  [ValidateNotNullOrEmpty()][string]$templateFilePath
  [string]$parameterFilePath
  [string]$azureLocation
  [ValidateNotNullOrEmpty()][string]$deploymentTargetResourceId
  [int]$httpTimeoutSeconds
  [int]$longRunningJobTimeoutSeconds
  [ValidateRange(3, 10)][int]$maxRetry
  [ValidateSet('Failed', 'Succeeded')][string]$requiredWhatIfStatus
  [ValidateNotNullOrEmpty()][string]$token
  [ValidateNotNullOrEmpty()][System.Collections.Generic.List[PolicyViolationInfo]] $policyViolation

  # constructors
  WhatIfDeploymentTestConfig([string]$testName, [string]$token, [string]$templateFilePath, [string]$deploymentTargetResourceId, [string]$requiredWhatIfStatus) {
    $this.testName = $testName
    $this.templateFilePath = $templateFilePath
    $this.deploymentTargetResourceId = $deploymentTargetResourceId
    $this.token = $token
    $this.requiredWhatIfStatus = $requiredWhatIfStatus
  }

  WhatIfDeploymentTestConfig([string]$testName, [string]$token, [string]$templateFilePath, [string]$deploymentTargetResourceId, [string]$requiredWhatIfStatus, [PolicyViolationInfo[]]$policyViolation) {
    $this.testName = $testName
    $this.templateFilePath = $templateFilePath
    $this.deploymentTargetResourceId = $deploymentTargetResourceId
    $this.requiredWhatIfStatus = $requiredWhatIfStatus
    $this.token = $token
    $this.policyViolation = $policyViolation
  }

  # Default constructor
  WhatIfDeploymentTestConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  WhatIfDeploymentTestConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

class ManualWhatIfTestConfig {
  [ValidateNotNullOrEmpty()][string]$testName
  [Object[]] $actualPolicyViolation
  [System.Collections.Generic.List[PolicyViolationInfo]] $desiredPolicyViolation

  # constructors
  ManualWhatIfTestConfig([string]$testName, [Object[]] $actualPolicyViolation, [PolicyViolationInfo[]]$desiredPolicyViolation) {
    $this.testName = $testName
    $this.actualPolicyViolation = $actualPolicyViolation
    $this.desiredPolicyViolation = $desiredPolicyViolation
  }

  # Default constructor
  ManualWhatIfTestConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  ManualWhatIfTestConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

class TerraformPolicyRestrictionTestConfig {
  [ValidateNotNullOrEmpty()][string]$testName
  [ValidateNotNullOrEmpty()][string]$terraformDirectory
  [ValidateNotNullOrEmpty()][string]$token
  [ValidateNotNullOrEmpty()][System.Collections.Generic.List[PolicyRestrictionViolationInfo]] $policyViolation

  # constructors
  TerraformPolicyRestrictionTestConfig([string]$testName, [string]$token, [string]$terraformDirectory, [PolicyRestrictionViolationInfo[]]$policyViolation) {
    $this.testName = $testName
    $this.terraformDirectory = $terraformDirectory
    $this.token = $token
    $this.policyViolation = $policyViolation
  }

  # Default constructor
  TerraformPolicyRestrictionTestConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  TerraformPolicyRestrictionTestConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

# This class is used to represent the resource config for the Azure Policy restriction API call.
class PolicyRestrictionResourceConfig {
  [ValidateNotNullOrEmpty()][string]$resourceName
  [ValidateNotNullOrEmpty()][string]$resourceType
  [ValidateNotNullOrEmpty()][string]$apiVersion
  [ValidateNotNullOrEmpty()][string]$resourceContent
  [string]$location
  [string]$resourceScope
  [bool]$includeAuditEffect

  # constructors
  #only mandatory parameters
  PolicyRestrictionResourceConfig([string]$resourceName, [string]$resourceType, [string]$apiVersion, [string]$resourceContent) {
    $this.resourceName = $resourceName
    $this.resourceType = $resourceType
    $this.apiVersion = $apiVersion
    $this.resourceContent = $resourceContent
  }

  #mandatory parameters with location and includeAuditEffect
  PolicyRestrictionResourceConfig([string]$resourceName, [string]$resourceType, [string]$apiVersion, [string]$resourceContent, [string]$location, [bool]$includeAuditEffect) {
    $this.resourceName = $resourceName
    $this.resourceType = $resourceType
    $this.apiVersion = $apiVersion
    $this.resourceContent = $resourceContent
    $this.location = $location
    $this.includeAuditEffect = $includeAuditEffect
  }

  #all parameters
  PolicyRestrictionResourceConfig([string]$resourceName, [string]$resourceType, [string]$apiVersion, [string]$resourceContent, [string]$location, [bool]$includeAuditEffect, [string]$resourceScope) {
    $this.resourceName = $resourceName
    $this.resourceType = $resourceType
    $this.apiVersion = $apiVersion
    $this.resourceContent = $resourceContent
    $this.location = $location
    $this.includeAuditEffect = $includeAuditEffect
    $this.resourceScope = $resourceScope
  }

  # Default constructor
  PolicyRestrictionResourceConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  PolicyRestrictionResourceConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}

#this class is used to represent the resource config for the Azure Policy restriction API call for specific arm configurations
class ArmPolicyRestrictionTestConfig {
  [ValidateNotNullOrEmpty()][string]$testName
  [ValidateNotNullOrEmpty()][PolicyRestrictionResourceConfig]$resourceConfig
  [ValidateNotNullOrEmpty()][string]$deploymentTargetResourceId
  [ValidateNotNullOrEmpty()][string]$token
  [ValidateNotNullOrEmpty()][System.Collections.Generic.List[PolicyRestrictionViolationInfo]] $policyViolation

  # constructors
  ArmPolicyRestrictionTestConfig([string]$testName, [string]$token, [PolicyRestrictionResourceConfig]$resourceConfig, [string]$deploymentTargetResourceId, [PolicyRestrictionViolationInfo[]]$policyViolation) {
    $this.testName = $testName
    $this.resourceConfig = $resourceConfig
    $this.deploymentTargetResourceId = $deploymentTargetResourceId
    $this.token = $token
    $this.policyViolation = $policyViolation
  }

  # Default constructor
  ArmPolicyRestrictionTestConfig() { $this.Init(@{}) }
  # Convenience constructor from hashtable
  ArmPolicyRestrictionTestConfig([hashtable]$Properties) { $this.Init($Properties) }
  # Shared initializer method
  [void] Init([hashtable]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }
  }
}
