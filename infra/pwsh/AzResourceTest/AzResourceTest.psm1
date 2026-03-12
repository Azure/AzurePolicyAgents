using module ./AzResourceTest-type.psm1
using module ./AzResourceTest-helper.psm1
using module ./AzResourceTest-terraform-helper.psm1
using module ./AzResourceTest-bicep-helper.psm1

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTPropertyValueTestConfig {
  [OutputType([PropertyValueTestConfig])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  Param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [ValidateNotNullOrEmpty()]
    [string]$token,

    [parameter(Mandatory = $true, Position = 2, HelpMessage = "The resource Id to check.")]
    [ValidateNotNullOrEmpty()]
    [string]$resourceId,

    [parameter(Mandatory = $true, Position = 3, HelpMessage = "Type of the resource property value. Supported types are 'string', 'number', 'boolean'.")]
    [ValidateSet('string', 'number', 'boolean')]
    [string]$valueType,

    [parameter(Mandatory = $true, Position = 4, HelpMessage = "The resource property to check.")]
    [ValidateNotNullOrEmpty()]
    [string]$property,

    [parameter(Mandatory = $true, Position = 5, HelpMessage = "The condition of the value comparison. Supported values are 'equals', 'notEquals', 'greater', 'less', 'greaterequal', 'lessequal'.")]
    [ValidateSet('equals', 'notEquals', 'greater', 'less', 'greaterequal', 'lessequal')]
    [string]$condition,

    [parameter(Mandatory = $true, Position = 6, HelpMessage = 'The desired value of the property.')]
    [ValidateNotNullOrEmpty()]
    [string]$value,

    [parameter(Mandatory = $false, HelpMessage = 'The resource type.')]
    [string]$resourceType,

    [parameter(Mandatory = $false, HelpMessage = 'The Azure Resource Manager API version.')]
    [string]$apiVersion
  )
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new PropertyValueTestConfig") -eq $true) {
    $properties = @{
      testName   = $testName
      token      = $token
      resourceId = $resourceId
      valueType  = $valueType
      property   = $property
      condition  = $condition
      value      = $value
    }
    if ($PSBoundParameters.ContainsKey('resourceType')) {
      $properties.Add('resourceType', $resourceType)
    }
    if ($PSBoundParameters.ContainsKey('apiVersion')) {
      $properties.Add('apiVersion', $apiVersion)
    }
    $PropertyValueTestConfig = [PropertyValueTestConfig]::new($properties)
  }
  $PropertyValueTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTPropertyCountTestConfig {
  [OutputType([PropertyCountTestConfig])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  Param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [ValidateNotNullOrEmpty()]
    [string]$token,

    [parameter(Mandatory = $true, Position = 2, HelpMessage = "The resource Id to check.")]
    [ValidateNotNullOrEmpty()]
    [string]$resourceId,

    [parameter(Mandatory = $true, Position = 3, HelpMessage = "The resource property to check.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$property,

    [parameter(Mandatory = $true, Position = 4, HelpMessage = "The condition of the value comparison. Supported values are 'equals', 'notEquals', 'greater', 'less', 'greaterequal', 'lessequal'.")]
    [ValidateSet('equals', 'notEquals', 'greater', 'less', 'greaterequal', 'lessequal')]
    [string]$condition,

    [parameter(Mandatory = $true, Position = 5, HelpMessage = "The desired count of the property value.")]
    [ValidateNotNullOrEmpty()]
    [int]$count,

    [parameter(Mandatory = $false, Position = 6, HelpMessage = "The operator to use when multiple properties are provided. Supported values are 'and', 'or', 'concat'.")]
    [ValidateSet('and', 'or', 'concat')]
    [string]$operator,

    [parameter(Mandatory = $false, HelpMessage = 'The resource type.')]
    [string]$resourceType,

    [parameter(Mandatory = $false, HelpMessage = 'The Azure Resource Manager API version.')]
    [string]$apiVersion
  )
  if ($property.Count -gt 1 -and -not $operator) {
    throw "the 'operator' parameter is required when multiple properties are provided"
  }
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new PropertyCountTestConfig") -eq $true) {
    If ($PSCmdlet.ShouldProcess($testName, "Creating a new PropertyCountTestConfig") -eq $true) {
      $properties = @{
        testName   = $testName
        token      = $token
        resourceId = $resourceId
        property   = $property
        condition  = $condition
        count      = $count
      }
      if ($PSBoundParameters.ContainsKey('operator')) {
        $properties.Add('operator', $operator)
      }
      if ($PSBoundParameters.ContainsKey('resourceType')) {
        $properties.Add('resourceType', $resourceType)
      }
      if ($PSBoundParameters.ContainsKey('apiVersion')) {
        $properties.Add('apiVersion', $apiVersion)
      }
      $PropertyCountTestConfig = [PropertyCountTestConfig]::new($properties)

    }
  }
  $PropertyCountTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTPolicyStateTestConfig {
  [OutputType([PolicyStateTestConfig])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  Param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [ValidateNotNullOrEmpty()]
    [string]$token,

    [parameter(Mandatory = $true, Position = 2, HelpMessage = "The resource Id to check.")]
    [ValidateNotNullOrEmpty()]
    [string]$resourceId,

    [parameter(Mandatory = $true, Position = 3, HelpMessage = "The policy assignment Id to check.")]
    [ValidateNotNullOrEmpty()]
    [string]$policyAssignmentId,

    [parameter(Mandatory = $true, Position = 4, HelpMessage = "The desired compliance state of the policy assignment.")]
    [ValidateSet('Compliant', 'NonCompliant')]
    [string]$requiredComplianceState,

    [parameter(Mandatory = $false, Position = 5, HelpMessage = "When a policy initiative is assigned, the policy definition reference Id to check. If not specified, the test will check the compliance state of the policy assignment.")]
    [string]$policyDefinitionReferenceId
  )
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new PolicyStateTestConfig") -eq $true) {
    $PolicyStateTestConfig = [PolicyStateTestConfig]::new($testName, $token, $resourceId, $policyAssignmentId, $requiredComplianceState)
    if ($policyDefinitionReferenceId) {
      $PolicyStateTestConfig.policyDefinitionReferenceId = $policyDefinitionReferenceId
    }
  }
  $PolicyStateTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTResourceExistenceTestConfig {
  [OutputType([ResourceExistenceTestConfig])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  Param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [ValidateNotNullOrEmpty()]
    [string]$token,

    [parameter(Mandatory = $true, Position = 2, HelpMessage = "The resource Id to check.")]
    [ValidateNotNullOrEmpty()]
    [string]$resourceId,

    [parameter(Mandatory = $true, Position = 3, HelpMessage = "The desired condition of the resource existence test. Supported values are 'exists' and 'notExists'.")]
    [ValidateSet('exists', 'notExists')]
    [string]$condition,

    [parameter(Mandatory = $false, Position = 4, HelpMessage = "The Azure resource provider API version. When this parameter is not provided, the test will try to locate the resource using Azure Resource Graph. This value must be provided if the specific resource type is not supported by Azure Resource Graph.")]
    [string]$apiVersion
  )
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new ResourceExistenceTestConfig") -eq $true) {
    $ResourceExistenceTestConfig = [ResourceExistenceTestConfig]::new($testName, $token, $resourceId, $condition)
    if ($apiVersion) {
      $ResourceExistenceTestConfig.apiVersion = $apiVersion
    }
  }
  $ResourceExistenceTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTWhatIfDeploymentTestConfig {
  [OutputType([WhatIfDeploymentTestConfig])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [ValidateNotNullOrEmpty()]
    [string]$token,

    [parameter(Mandatory = $true, Position = 2, HelpMessage = "The path to the Azure Bicep or ARM template file.")]
    [ValidateScript({ test-path $_ -PathType Leaf })]
    [string]$templateFilePath,

    [parameter(Mandatory = $true, Position = 3, HelpMessage = "The resource Id of the deployment target. i.e. the subscription or resource group resource Id.")]
    [ValidateNotNullOrEmpty()][string]$deploymentTargetResourceId,

    [parameter(Mandatory = $true, Position = 4, HelpMessage = "The required status of the What-If deployment. Supported values are 'Failed' and 'Succeeded'.")]
    [ValidateSet('Failed', 'Succeeded')]
    [string]$requiredWhatIfStatus,

    [parameter(Mandatory = $false, Position = 5, HelpMessage = "The desired policy violation information for the What-If deployment test.")]
    [PolicyViolationInfo[]]$policyViolation,

    [parameter(Mandatory = $false, HelpMessage = "Optional. The path to the parameter file for the Bicep or ARM template.")]
    [ValidateScript({ test-path $_ -PathType Leaf })]
    [string]$parameterFilePath,

    [parameter(Mandatory = $false, HelpMessage = 'The HTTP timeout in seconds for the What-If deployment REST API request. The default value is 300 seconds.')]
    [ValidateRange(100, 1000)]
    [int]$httpTimeoutSeconds = 300,

    [parameter(Mandatory = $false, HelpMessage = "The maximum time in seconds for the long-running what-if evaluation to finish. The default value is 300 seconds.")]
    [ValidateRange(300, 1000)]
    [int]$longRunningJobTimeoutSeconds = 300,

    [parameter(Mandatory = $false, HelpMessage = "The maximum number of retries for the long-running what-if evaluation. The default value is 3.")]
    [ValidateRange(3, 10)]
    [int]$maxRetry = 3,

    [parameter(Mandatory = $false, HelpMessage = "The Azure location for the deployment. The default value is 'australiaeast'. This value is used when the deployment scope is not at Resource Group level.")]
    [string]$azureLocation = 'australiaeast'
  )
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new WhatIfDeploymentTestConfig") -eq $true) {
    $WhatIfDeploymentTestConfig = [WhatIfDeploymentTestConfig]::new($testName, $token, $templateFilePath, $deploymentTargetResourceId, $requiredWhatIfStatus)
    if ($policyViolation) {
      $WhatIfDeploymentTestConfig.policyViolation = $policyViolation
    }
    if ($parameterFilePath) {
      $WhatIfDeploymentTestConfig.parameterFilePath = $parameterFilePath
    }
    $WhatIfDeploymentTestConfig.httpTimeoutSeconds = $httpTimeoutSeconds
    $WhatIfDeploymentTestConfig.longRunningJobTimeoutSeconds = $longRunningJobTimeoutSeconds
    $WhatIfDeploymentTestConfig.maxRetry = $maxRetry
    $WhatIfDeploymentTestConfig.azureLocation = $azureLocation
  }

  $WhatIfDeploymentTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTManualWhatIfTestConfig {
  [OutputType([ManualWhatIfTestConfig])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The actual policy violation returned from ARM REST API calls for the manual What-If validation test.")]
    [object[]]$actualPolicyViolation,

    [parameter(Mandatory = $false, Position = 2, HelpMessage = "The desired policy violation information for the manual What-If validation test.")]
    [PolicyViolationInfo[]]$desiredPolicyViolation
  )
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new ManualWhatIfTestConfig") -eq $true) {
    $ManualWhatIfTestConfig = [ManualWhatIfTestConfig]::new($testName, $actualPolicyViolation, $desiredPolicyViolation)
  }

  $ManualWhatIfTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTTerraformPolicyRestrictionTestConfig {
  [OutputType([TerraformPolicyRestrictionTestConfig])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [ValidateNotNullOrEmpty()]
    [string]$token,

    [parameter(Mandatory = $true, Position = 2, HelpMessage = "The path to the Terraform file directory.")]
    [ValidateScript({ test-path $_ -PathType Container })]
    [string]$terraformDirectory,

    [parameter(Mandatory = $true, Position = 3, HelpMessage = "The desired policy violation information for the Terraform Plan test.")]
    [PolicyRestrictionViolationInfo[]]$policyViolation
  )
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new TerraformPolicyRestrictionTestConfig") -eq $true) {
    $terraformPolicyRestrictionTestConfig = [TerraformPolicyRestrictionTestConfig]::new($testName, $token, $terraformDirectory, $policyViolation)
  }

  $terraformPolicyRestrictionTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTArmPolicyRestrictionTestConfig {
  [OutputType([ArmPolicyRestrictionTestConfig])]
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [ValidateNotNullOrEmpty()]
    [string]$token,

    [parameter(Mandatory = $true, Position = 2, HelpMessage = "The resource Id of the deployment scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$deploymentTargetResourceId,

    [parameter(Mandatory = $true, Position = 3, HelpMessage = "The ARM resource configuration for the policy restriction validation.")]
    [PolicyRestrictionResourceConfig]$resourceConfig,

    [parameter(Mandatory = $true, Position = 4, HelpMessage = "The desired policy violation information for the ARM resource configuration.")]
    [PolicyRestrictionViolationInfo[]]$policyViolation
  )
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new ArmPolicyRestrictionTestConfig") -eq $true) {
    $armPolicyRestrictionTestConfig = [ArmPolicyRestrictionTestConfig]::new($testName, $token, $resourceConfig, $deploymentTargetResourceId, $policyViolation)
  }

  $armPolicyRestrictionTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function New-ARTManualWhatIfTestConfig {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the pester test.")]
    [ValidateNotNullOrEmpty()]
    [string]$testName,

    [parameter(Mandatory = $true, Position = 1, HelpMessage = "The actual policy violation returned from ARM REST API calls for the manual What-If validation test.")]
    [object[]]$actualPolicyViolation,

    [parameter(Mandatory = $false, Position = 2, HelpMessage = "The desired policy violation information for the manual What-If validation test.")]
    [PolicyViolationInfo[]]$desiredPolicyViolation
  )
  if ($PSCmdlet.ShouldProcess($testName, "Creating a new ManualWhatIfTestConfig") -eq $true) {
    $ManualWhatIfTestConfig = [ManualWhatIfTestConfig]::new($testName, $actualPolicyViolation, $desiredPolicyViolation)
  }

  $ManualWhatIfTestConfig
}

# .EXTERNALHELP AzResourceTest-help.xml
function Get-ARTResourceConfiguration {
  [OutputType([string])]
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $false, ParameterSetName = 'PredefinedQuery', HelpMessage = "the scope for the ARG search query. This can be a subscription id, subscription name, or a management group name")]
    [parameter(Mandatory = $false, ParameterSetName = 'CustomQuery', HelpMessage = "the scope for the ARG search query. This can be a subscription id, subscription name, or a management group name")]
    [ValidateNotNullOrEmpty()]
    [string]$Scope,

    [parameter(Mandatory = $true, ParameterSetName = 'PredefinedQuery', HelpMessage = "the scope type for the ARG search query. Possible values are 'subscription' and 'managementGroup'")]
    [parameter(Mandatory = $true, ParameterSetName = 'CustomQuery', HelpMessage = "the scope type for the ARG search query. Possible values are 'subscription' and 'managementGroup'")]
    [ValidateSet("subscription", "managementGroup", "tenant")]
    [string]$ScopeType,

    [parameter(Mandatory = $true, ParameterSetName = 'PredefinedQuery', HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [parameter(Mandatory = $true, ParameterSetName = 'CustomQuery', HelpMessage = "The Azure OAuth token. This is required to invoke the Azure Resource Manager REST APIs.")]
    [ValidateNotNullOrEmpty()]
    [string]$Token,

    [parameter(Mandatory = $true, ParameterSetName = 'PredefinedQuery', HelpMessage = "the resource type to search for in Azure resource graph.")]
    [ValidateNotNullOrEmpty()]
    [string]$resourceType,

    [parameter(Mandatory = $false, ParameterSetName = 'PredefinedQuery', HelpMessage = "Optional. The table to search for in Azure Resource Graph.")]
    [ValidateNotNullOrEmpty()]
    [string]$azureResourceGraphTable,

    [parameter(Mandatory = $false, ParameterSetName = 'PredefinedQuery', HelpMessage = "the resource Ids to search for in Azure resource graph.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$resourceIds,

    [parameter(Mandatory = $true, ParameterSetName = 'CustomQuery', HelpMessage = "the custom ARG search query.")]
    [string]$customQuery
  )

  #Suppress the Az PS module warning messages
  Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

  #build ARG query

  if ($PSCmdlet.ParameterSetName -ieq 'PredefinedQuery') {
    if (!$PSBoundParameters.ContainsKey('azureResourceGraphTable')) {
      $azureResourceGraphTable = getARGTable -resourceType $resourceType
    }

    $query = @"
$azureResourceGraphTable
| where type =~ '$resourceType'
"@

    if ($resourceIds) {
      #Add the resource Id to each pre-defined query
      $arrResourceId = @()
      foreach ($item in $resourceIds) {
        $arrResourceId += "'$($item.tolower())'"
      }
      $strResourceId = $arrResourceId -join ','

      $query = @"
$query
| where tolower(id) in ($strResourceId)
"@
    }
  } else {
    $query = $customQuery
  }
  Write-Verbose "[$(getCurrentUTCString)]: The query is:" -Verbose
  Write-Verbose $query -verbose

  #Invoke ARG query
  if ($ScopeType -ine 'tenant') {
    $QueryResult = invokeARGQuery -scope $validatedScope -scopeType $ScopeType -query $query -token $Token
  } else {
    $QueryResult = invokeARGQuery -query $query -scopeType $ScopeType -token $Token
  }
  if ($PSCmdlet.ParameterSetName -ieq 'PredefinedQuery') {
    Write-Verbose "[$(getCurrentUTCString)]: $($QueryResult.count) resources are found from table Azure Resource Graph table '$azureResourceGraphTable'."
  } else {
    Write-Verbose "[$(getCurrentUTCString)]: $($QueryResult.count) resources are found from the custom query."
  }
  $resources = $QueryResult | ConvertTo-Json -Depth 99 -AsArray

  Write-verbose "[$(getCurrentUTCString)]: Number of resources found: $($resources.count)" -verbose
  $resources
}

# .EXTERNALHELP AzResourceTest-help.xml
function Test-ARTResourceConfiguration {
  [OutputType([System.String])]
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = "The tests to run against the resource configuration.")]
    [object[]]$tests,

    [Parameter(Mandatory = $true, HelpMessage = "The title of the Pester Test. This is the name of the Pester Describe block.")]
    [string]$testTitle,

    [Parameter(Mandatory = $true, HelpMessage = "The title of the Pester Context block.")]
    [string]$contextTitle,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the test suite.")]
    [string]$testSuiteName,

    [Parameter(Mandatory = $true, ParameterSetName = 'ProduceOutputFile', Position = 5, HelpMessage = "The path to the output file.")]
    [ValidateNotNullOrEmpty()][string]$OutputFile,

    [Parameter(Mandatory = $false, ParameterSetName = 'ProduceOutputFile', Position = 6, HelpMessage = "The output format of the test result. Supported values are 'NUnitXml' and 'LegacyNUnitXML'")]
    [ValidateSet('NUnitXml', 'LegacyNUnitXML')][string]$OutputFormat = 'NUnitXml'
  )
  #Pester test file
  $azResourceConfigTestFilePath = join-path $PSScriptRoot 'Az.Resource.Tests.ps1'
  Write-verbose "[$(getCurrentUTCString)]: Az resource configuration test file path: '$azResourceConfigTestFilePath'"
  Write-Verbose "[$(getCurrentUTCString)]: Testing '$testTitle'..."
  $testData = @{
    tests        = $tests
    testTitle    = $testTitle
    contextTitle = $contextTitle
  }

  $configTestContainer = New-PesterContainer -Path $azResourceConfigTestFilePath -Data $testData
  $configTestConfig = New-PesterConfiguration
  $configTestConfig.Run.Container = $configTestContainer
  $configTestConfig.Run.PassThru = $true
  $configTestConfig.Output.verbosity = 'Detailed'

  $configTestConfig.TestResult.Enabled = $true
  $configTestConfig.TestResult.TestSuiteName = $testSuiteName

  If ($PSCmdlet.ParameterSetName -eq 'ProduceOutputFile') {
    $configTestConfig.TestResult.OutputFormat = $OutputFormat
    $configTestConfig.TestResult.OutputPath = $OutputFile
  }

  Write-verbose "[$(getCurrentUTCString)]: Invoking Pester test $testTitle" -verbose
  Invoke-Pester -Configuration $configTestConfig

}
