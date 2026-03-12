<# Test
$resourceId = '/subscriptions/46aa6fb9-01f8-4acc-b67c-ee355f6b6fa0/resourceGroups/rg-tytest-stg1-01/providers/Microsoft.Storage/storageAccounts/satyteststg101'
./tests.ps1 -resourceId $resourceId
#>
using module ../../../ps_modules/AzResourceTest/AzResourceTest.psm1

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').path

#load helper
. $helperFunctionScriptPath

#variables
$deploymentOutputs = $env:bicepDeploymentOutputs
$deploymentId = $env:bicepDeploymentId
$deploymentTarget = $env:bicepDeploymentTarget
$deploymentScope = $env:bicepDeploymentScope
$outputFilePath = $env:outputFilePath
$outputFormat = $env:outputFormat
#Parse deployment outputs
Write-Verbose "Deployment Outputs: $deploymentOutputs" -Verbose
$deploymentOutputsJson = $deploymentOutputs | ConvertFrom-Json -Depth 99
$resourceId = $deploymentOutputsJson.resourceId.value
$token = $(az account get-access-token --resource 'https://management.azure.com/' | convertfrom-json).accessToken
$testTitle = "Storage Account Configuration Test"
$contextTitle = "Storage Configuration"
$testSuiteName = 'StorageAccountTest'
$diagnosticSettingsIdSuffix = '/providers/microsoft.insights/diagnosticSettings/setByPolicyLAW'
$diagnosticSettingsAPIVersion = '2021-05-01-preview'
$resourceName = ($resourceId -split ('/'))[-1]

$gitRoot = Get-GitRoot
$globalTestConfigFilePath = join-path $gitRoot 'tests' '.shared' '.config' 'policy_integration_test_config.jsonc'
$localTestConfigFilePath = join-path $PSScriptRoot 'config.json'
$globalTestConfig = getTestConfig -TestConfigFilePath $globalTestConfigFilePath
$localTestConfig = getTestConfig -TestConfigFilePath $localTestConfigFilePath
$privateDNSSubscriptionName = $globalTestConfig.privateDNSSubscription
$testSubscriptionName = $localTestConfig.testSubscription
$privateDNSSubscriptionId = $globalTestConfig.Subscriptions.$privateDNSSubscriptionName.id
$testSubscriptionId = $globalTestConfig.Subscriptions.$testSubscriptionName.id
$testResourceGroup = $localTestConfig.testResourceGroup
$privateDNSResourceGroup = $globalTestConfig.privateDNSResourceGroup
$whatIfMaxRetry = $globalTestConfig.whatIfMaxRetry
$storageAccountPolicyAssignmentName = $localTestConfig.storageAccountAssignmentName
$testMG = $localTestConfig.testManagementGroup
$storagePolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $testMG, $storageAccountPolicyAssignmentName
$whatIfDeploymentTargetResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubscriptionId, $testResourceGroup
$whatIfSuccessTemplatePath = join-path $PSScriptRoot 'main.good.bicep'
$whatIfFailedTemplatePath = join-path $PSScriptRoot 'main.bad.bicep'
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $diagnosticSettingsIdSuffix
$blobPrivateDNSARecordId = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net/A/{2}" -f $privateDNSSubscriptionId, $privateDNSResourceGroup, $resourceName
Write-Verbose "blobPrivateDNSARecordId: $blobPrivateDNSARecordId" -Verbose
Write-Verbose "whatIfDeploymentTargetResourceId: $whatIfDeploymentTargetResourceId" -Verbose

$violatingPolicies = @(
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-010'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-008'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-009'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-012'
  }
)


#define tests
$tests = @()
#Modify / Append Policies
#TAG-005 rg-inherit-tag-from-sub (SolutionID)
$tests += New-ARTPropertyCountTestConfig 'TAG-005: Resource Group Should have SolutionID tag' $token $deploymentTarget 'tags.SolutionID' 'equals' 1

#TAG-006 rg-inherit-tag-from-sub (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-006: Resource Group Should have dataclass tag' $token $deploymentTarget 'tags.dataclass' 'equals' 1

#TAG-007 rg-inherit-tag-from-sub (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-007: Resource Group Should have owner tag' $token $deploymentTarget 'tags.owner' 'equals' 1

#TAG-008 rg-inherit-tag-from-sub (supportteam)
$tests += New-ARTPropertyCountTestConfig 'TAG-008: Resource Group Should have supportteam tag' $token $deploymentTarget 'tags.supportteam' 'equals' 1

#TAG-018 rg-inherit-tag-from-sub (environment)
$tests += New-ARTPropertyCountTestConfig 'TAG-018: Resource Group Should have environment tag' $token $deploymentTarget 'tags.environment' 'equals' 1

#TAG-009 all-inherit-tag-from-rg (SolutionID)
$tests += New-ARTPropertyCountTestConfig 'TAG-009: Resource Should have SolutionID tag' $token $resourceId 'tags.SolutionID' 'equals' 1

#TAG-010 all-inherit-tag-from-rg (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-010: Resource Should have dataclass tag' $token $resourceId 'tags.dataclass' 'equals' 1

#TAG-011 all-inherit-tag-from-rg (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-011: Resource Should have owner tag' $token $resourceId 'tags.owner' 'equals' 1

#TAG-012 all-inherit-tag-from-rg (supportteam)
$tests += New-ARTPropertyCountTestConfig 'TAG-012: Resource Should have supportteam tag' $token $resourceId 'tags.supportteam' 'equals' 1

#TAG-019 all-inherit-tag-from-rg (environment)
$tests += New-ARTPropertyCountTestConfig 'TAG-019: Resource Should have environment tag' $token $resourceId 'tags.environment' 'equals' 1

$tests += New-ARTPropertyValueTestConfig 'STG-005: Network ACL Default Action Should be Deny' $token $resourceId 'string' 'properties.networkAcls.defaultAction' 'equals' 'Deny'
$tests += New-ARTPropertyValueTestConfig 'STG-002: Double Encryption must be enabled' $token $resourceId 'boolean' 'properties.encryption.requireInfrastructureEncryption' 'equals' $true
$tests += New-ARTPropertyValueTestConfig 'STG-010: Minimum TLS version should be TLS1.2' $token $resourceId 'string' 'properties.minimumTlsVersion' 'equals' 'TLS1_2'
$tests += New-ARTPropertyValueTestConfig 'STG-007: Shared Key Access must be disabled' $token $resourceId 'boolean' 'properties.allowSharedKeyAccess' 'equals' $false
$tests += New-ARTPropertyValueTestConfig 'STG-002: Storage account encryption scopes should use double encryption for data at rest' $token $resourceId 'boolean' 'properties.supportsHttpsTrafficOnly' 'equals' $true
$tests += New-ARTPropertyCountTestConfig 'Should Use Private Endpoints' $token $resourceId @('properties.privateEndpointConnections', 'properties.manualPrivateEndpointConnections') 'greaterequal' 1 'concat'
$tests += New-ARTPolicyStateTestConfig 'STG-001: Audit CMK Encryption policy should be NonCompliant' $token $resourceId $storagePolicyAssignmentId 'NonCompliant' 'STG-001'
$tests += New-ARTResourceExistenceTestConfig 'Diagnostic Settings Must Be Configured' $token $diagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion
$tests += New-ARTResourceExistenceTestConfig 'Private DNS Record for Blob PE must exist' $token $blobPrivateDNSARecordId 'exists'
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $token $whatIfSuccessTemplatePath $whatIfDeploymentTargetResourceId 'Succeeded' -maxRetry $whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $token $whatIfFailedTemplatePath $whatIfDeploymentTargetResourceId 'Failed' $violatingPolicies -maxRetry $whatIfMaxRetry
#Invoke tests
$params = @{
  tests         = $tests
  testTitle     = $testTitle
  contextTitle  = $contextTitle
  testSuiteName = $testSuiteName
  OutputFile    = $outputFilePath
  OutputFormat  = $outputFormat

}
Test-ARTResourceConfiguration @params
