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
Write-Verbose "Output File Path: $outputFilePath" -Verbose
Write-Verbose "Output Format: $outputFormat" -Verbose
$deploymentOutputsJson = $deploymentOutputs | ConvertFrom-Json -Depth 99
$resourceId = $deploymentOutputsJson.resourceId.value
$testTitle = "Key Vault Configuration Test"
$contextTitle = "Key Vault Configuration"
$testSuiteName = 'KeyVaultTest'
$diagnosticSettingsIdSuffix = '/providers/microsoft.insights/diagnosticSettings/setByPolicyLAW'
$diagnosticSettingsAPIVersion = '2021-05-01-preview'
$resourceName = ($resourceId -split ('/'))[-1]
$token = $(az account get-access-token --resource 'https://management.azure.com/' | convertfrom-json).accessToken
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
$testMG = $localTestConfig.testManagementGroup
$kvPolicyAssignmentName = $localTestConfig.keyVaultAssignmentName
$keyVaultPolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $testMG, $kvPolicyAssignmentName

$whatIfDeploymentTargetResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubscriptionId, $testResourceGroup
$whatIfSuccessTemplatePath = join-path $PSScriptRoot 'main.good.bicep'
$whatIfFailedTemplatePath = join-path $PSScriptRoot 'main.bad.bicep'
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $diagnosticSettingsIdSuffix
$kvPrivateDNSARecordId = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/A/{2}" -f $privateDNSSubscriptionId, $privateDNSResourceGroup, $resourceName
Write-Verbose "kvPrivateDNSARecordId: $kvPrivateDNSARecordId" -Verbose
Write-Verbose "whatIfDeploymentTargetResourceId: $whatIfDeploymentTargetResourceId" -Verbose

#define violating deny policies
$violatingPolicies = @(
  @{
    policyAssignmentId          = $keyVaultPolicyAssignmentId
    policyDefinitionReferenceId = 'pol-enforce-kv-rbac-authorization' #kv-should-use-rbac (KeyVault permission model should be configured to use Azure RBAC)
  }
)

#define tests
$tests = @()
#Modify / Append Policies

#TAG-006 rg-inherit-tag-from-sub (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-006: Resource Group Should have dataclass tag' $token $deploymentTarget 'tags.dataclass' 'equals' 1

#TAG-007 rg-inherit-tag-from-sub (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-007: Resource Group Should have owner tag' $token $deploymentTarget 'tags.owner' 'equals' 1

#region Audit / AuditIfNotExists policies

#98728c90-32c7-4049-8429-847dc0f4fe37 (Key Vault secrets should have an expiration date)
#$tests += New-ARTPolicyStateTestConfig 'Key Vault secrets should have an expiration date' $resourceId $keyVaultPolicyAssignmentId 'NonCompliant' '98728c90-32c7-4049-8429-847dc0f4fe37'

#pol-audit-deny-kv-public-network-access
$tests += New-ARTPolicyStateTestConfig 'Azure Key Vault should disable public network access' $token $resourceId $keyVaultPolicyAssignmentId 'NonCompliant' 'pol-audit-deny-kv-public-network-access'
#endregion

#region Modify / Append Policies
# pol-append-kv-soft-Delete-purge-protection
$test += New-ARTPropertyValueTestConfig 'Key Vault should have purge protection enabled' $token $resourceId 'boolean' 'properties.enablePurgeProtection' 'equals' $true

#DeployIfNotExists Policies
#QHS01-233 pe-config-private-dns-zone-single-zone-all-regions
$tests += New-ARTResourceExistenceTestConfig 'Private DNS Record for Key Vault PE must exist' $token $kvPrivateDNSARecordId 'exists'

#QHS01-184 kv-config-diag-logs
$tests += New-ARTResourceExistenceTestConfig 'Diagnostic Settings for Key Vault Must Be Configured' $token $diagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion
#endregion

#region Deny policies
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $token $whatIfSuccessTemplatePath $whatIfDeploymentTargetResourceId 'Succeeded' -maxRetry $whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $token $whatIfFailedTemplatePath $whatIfDeploymentTargetResourceId 'Failed' $violatingPolicies -maxRetry $whatIfMaxRetry
#endregion

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
