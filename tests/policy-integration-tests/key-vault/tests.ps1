#Requires -Modules Az.Accounts, Az.PolicyInsights, Az.Resources
#Requires -Version 7.0
<#
The following policy definitions are tested:
  - Resource Group inherit the 'dataclass' tag from subscription
  - Resource Group inherit the 'owner' tag from subscription
  - Azure Key Vault should disable public network access (Audit)
  - Key Vault should have purge protection enabled (Modify)
  - Private DNS Record for Key Vault PE must exist (DeployIfNotExists)
  - Diagnostic Settings for Key Vault Must Be Configured (DeployIfNotExists)
  - KeyVault permission model should be configured to use Azure RBAC (Deny)


#>
using module ../../../infra/pwsh/AzResourceTest/AzResourceTest.psd1

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../.shared/helper-functions.ps1').path

#load helper
. $helperFunctionScriptPath

#Get variables from configuration files
$globalConfigFilePath = '../.shared/policy_integration_test_config.jsonc'
$globalTestConfig = getTestConfig -TestConfigFilePath $globalConfigFilePath
$testLocalConfigFileName = $globalTestConfig.testLocalConfigFileName
$testBicepTemplateName = $globalTestConfig.testBicepTemplateName
$testLocalConfigFilePath = Join-Path $PSScriptRoot $testLocalConfigFileName
$localTestConfig = getTestConfig -TestConfigFilePath $testLocalConfigFilePath

$outputFormat = $globalTestConfig.testOutputFormat
$testOutputFilePrefix = $globalTestConfig.testOutputFilePrefix
$env:testResourceGroup = $localTestConfig.testResourceGroup
$testSubscription = $localTestConfig.testSubscription
$env:testSubscriptionId = $globalTestConfig.Subscriptions.$testSubscription.id
$env:removeTestResourceGroup = $localTestConfig.removeTestResourceGroup
$testName = $localTestConfig.testName
$outputFilePath = "$testOutputFilePrefix-$testName`.xml"
#deploy test bicep template first
. ../.shared/deploy-policy-test-bicep-template.ps1 -TestPath $PSScriptRoot -BicepFileName $testBicepTemplateName -TestConfigFileName $testLocalConfigFileName

#capture deployment results
$deploymentOutputs = $env:bicepDeploymentOutputs
$deploymentProvisioningState = $env:provisioningState

$deploymentTarget = $env:bicepDeploymentTarget

If ($deploymentProvisioningState -ne 'Succeeded') {
  Write-Output "Deployment provisioning state is '$deploymentProvisioningState'. Tests will be skipped."
  exit 1
} else {
  Write-Output "Deployment provisioning state is '$deploymentProvisioningState'. Since audit policies are tested, run policy compliance scan before proceeding with tests."
  Set-AzContext -Subscription $env:testSubscriptionId | Out-Null
  Write-Output "[$(getCurrentUTCString)]: Waiting for Policy compliance scan to finish for resource group '$env:testResourceGroup'."
  $job = Start-AzPolicyComplianceScan -ResourceGroupName $env:testResourceGroup -AsJob
  $job | wait-job
  Write-Output "[$(getCurrentUTCString)]: Policy compliance scan finished for resource group '$env:testResourceGroup'. Wait 1 minute for the results to be available before starting tests."
  Start-Sleep -Seconds 60
}

#Parse deployment outputs
Write-Verbose "[$(getCurrentUTCString)]: Deployment Outputs: $deploymentOutputs" -Verbose
Write-Verbose "[$(getCurrentUTCString)]: Output Format: $outputFormat" -Verbose
$deploymentOutputsJson = $deploymentOutputs | ConvertFrom-Json -Depth 99
$resourceId = $deploymentOutputsJson.resourceId.value
$testTitle = "$testName Configuration Test"
$contextTitle = "$testName Configuration"
$testSuiteName = 'KeyVaultTest'
$diagnosticSettingsIdSuffix = '/providers/microsoft.insights/diagnosticSettings/setByPolicyLAW'
$diagnosticSettingsAPIVersion = '2021-05-01-preview'
$resourceName = ($resourceId -split ('/'))[-1]
$token = convertfrom-securestring (get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText

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
    policyDefinitionReferenceId = 'KV-003' #KV-003: KeyVault permission model should be configured to use Azure RBAC
  }
)

#define tests
$tests = @()
#Modify / Append Policies

#TAG-006 rg-inherit-tag-from-sub (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-006: Resource Group Should have dataclass tag' $token $deploymentTarget 'tags.dataclass' 'equals' 1
$tests += New-ARTPropertyCountTestConfig 'TAG-007: Resource Group Should have owner tag' $token $deploymentTarget 'tags.owner' 'equals' 1
$test += New-ARTPropertyValueTestConfig 'KV-002: Key Vault should have purge protection enabled' $token $resourceId 'boolean' 'properties.enablePurgeProtection' 'equals' $true

#Audit / AuditIfNotExists policies

$tests += New-ARTPolicyStateTestConfig 'KV-004: Azure Key Vault should disable public network access' $token $resourceId $keyVaultPolicyAssignmentId 'NonCompliant' 'KV-004'

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-005: Private DNS Record for Key Vault PE must exist' $token $kvPrivateDNSARecordId 'exists'
$tests += New-ARTResourceExistenceTestConfig 'DS-029: Diagnostic Settings for Key Vault Must Be Configured' $token $diagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion

#Deny policies (testing both positive and engative scenarios)
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

#delete deployed resources
if ($deploymentProvisioningState -eq 'Succeeded') {
  Write-output "Remove deployed test resources."
  . ../.shared/delete-policy-test-deployed-resources.ps1
}