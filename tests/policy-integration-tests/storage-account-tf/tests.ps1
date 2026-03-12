using module ../../../ps_modules/AzResourceTest/AzResourceTest.psm1

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').path

#load helper
. $helperFunctionScriptPath

#variables
$testTitle = "Storage Account Configuration Test"
$contextTitle = "Storage Configuration"
$testSuiteName = 'StorageAccountTest'

$deploymentOutputs = $env:terraformDeploymentOutputs
$outputFilePath = $env:outputFilePath
$outputFormat = $env:outputFormat ? $env:outputFormat : 'NUnitXml'
Write-Output "Terraform Deployment Outputs: $deploymentOutputs"

$deploymentOutputsJson = $deploymentOutputs | ConvertFrom-Json -Depth 99
$resourceGroupId = $deploymentOutputsJson.resource_group_id.value
$storageAccountId = $deploymentOutputsJson.storage_account_id.value
#$storageAccountBlobPeId = $deploymentOutputsJson.storage_account_blob_pe_id.value

$localTestConfigFilePath = join-path $PSScriptRoot 'config.json'
$localTestConfig = getTestConfig -TestConfigFilePath $localTestConfigFilePath
$storageAccountPolicyAssignmentName = $localTestConfig.storageAccountAssignmentName
$testMG = $localTestConfig.testManagementGroup
$storagePolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $testMG, $storageAccountPolicyAssignmentName

$diagnosticSettingsIdSuffix = '/providers/microsoft.insights/diagnosticSettings/setByPolicyLAW'
$diagnosticSettingsAPIVersion = '2021-05-01-preview'
$diagnosticSettingsId = "{0}{1}" -f $storageAccountId, $diagnosticSettingsIdSuffix
$token = $(az account get-access-token --resource 'https://management.azure.com/' | convertfrom-json).accessToken

$violatingPolicies = @(
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-006'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-007'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Audit'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-009'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-010'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-012'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-008'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }

)
#define tests
$tests = @()

#Modify / Append Policies
#TAG-005 rg-inherit-tag-from-sub (SolutionID)
$tests += New-ARTPropertyCountTestConfig 'TAG-005: Resource Group Should have SolutionID tag' $token $resourceGroupId 'tags.SolutionID' 'equals' 1

#TAG-006 rg-inherit-tag-from-sub (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-006: Resource Group Should have dataclass tag' $token $resourceGroupId 'tags.dataclass' 'equals' 1

#TAG-007 rg-inherit-tag-from-sub (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-007: Resource Group Should have owner tag' $token $resourceGroupId 'tags.owner' 'equals' 1

#TAG-008 rg-inherit-tag-from-sub (supportteam)
$tests += New-ARTPropertyCountTestConfig 'TAG-008: Resource Group Should have supportteam tag' $token $resourceGroupId 'tags.supportteam' 'equals' 1

#TAG-018 rg-inherit-tag-from-sub (environment)
$tests += New-ARTPropertyCountTestConfig 'TAG-018: Resource Group Should have environment tag' $token $resourceGroupId 'tags.environment' 'equals' 1

#TAG-009 all-inherit-tag-from-rg (SolutionID)
$tests += New-ARTPropertyCountTestConfig 'TAG-009: Resource Should have SolutionID tag' $token $storageAccountId 'tags.SolutionID' 'equals' 1

#TAG-010 all-inherit-tag-from-rg (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-010: Resource Should have dataclass tag' $token $storageAccountId 'tags.dataclass' 'equals' 1

#TAG-011 all-inherit-tag-from-rg (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-011: Resource Should have owner tag' $token $storageAccountId 'tags.owner' 'equals' 1

#TAG-012 all-inherit-tag-from-rg (supportteam)
$tests += New-ARTPropertyCountTestConfig 'TAG-012: Resource Should have supportteam tag' $token $storageAccountId 'tags.supportteam' 'equals' 1

#TAG-019 all-inherit-tag-from-rg (environment)
$tests += New-ARTPropertyCountTestConfig 'TAG-019: Resource Should have environment tag' $token $storageAccountId 'tags.environment' 'equals' 1

$tests += New-ARTResourceExistenceTestConfig 'Diagnostic Settings Must Be Configured' $token $diagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion

#Deny policies
$tests += New-ARTTerraformPolicyRestrictionTestConfig -testName 'Violating Audit and Deny Policies should be detected from test Terraform template' -token $token -terraformDirectory $(join-path $PSScriptRoot 'main-bad-terraform') -policyViolation $violatingPolicies
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
