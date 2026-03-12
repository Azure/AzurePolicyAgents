using module ../../../ps_modules/AzResourceTest/AzResourceTest.psm1

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').path

#load helper
. $helperFunctionScriptPath

<#
Test cases:
- VNET-001: Gateway Subnet should not have Network Security Group associated (Deny)
- VNET-002: Subnets should be associated with a Network Security Group (Deny)
- VNET-003: Configure virtual networks to enable vnet flow log and traffic analytics (Australia East) (DeployIfNotExists)
- VNET-004: Configure virtual networks to enable vnet flow log and traffic analytics (Australia Southeast) (DeployIfNotExists)
- DS-058: Configure Diagnostic logging for Virtual Network (DeployIfNotExists)
#>
#variables
$deploymentOutputs = $env:deploymentOutputs
$deploymentId = $env:deploymentId
$deploymentScope = $env:deploymentScope
$outputFilePath = $env:outputFilePath
$outputFormat = $env:outputFormat
#Parse deployment outputs
$deploymentOutputsJson = $deploymentOutputs | ConvertFrom-Json -Depth 99
#Australia East VNet
$resourceId = $deploymentOutputsJson.resourceId.value
$resourceName = $deploymentOutputsJson.name.value

#Australia Southeast VNet
$aseVNetResourceName = $deploymentOutputsJson.aseVNetName.value
$aseVNetResourceId = $deploymentOutputsJson.aseVNetResourceId.value

$testTitle = "Virtual Network Configuration Test"
$contextTitle = "VNet Configuration"
$testSuiteName = 'VirtualNetworkTest'
$diagnosticSettingsIdSuffix = '/providers/microsoft.insights/diagnosticSettings/setByPolicy'
$diagnosticSettingsAPIVersion = '2021-05-01-preview'

$gitRoot = Get-GitRoot
$globalTestConfigFilePath = join-path $gitRoot 'tests' '.shared' '.config' 'policy_integration_test_config.jsonc'
$localTestConfigFilePath = join-path $PSScriptRoot 'config.json'
$globalTestConfig = getTestConfig -TestConfigFilePath $globalTestConfigFilePath
$localTestConfig = getTestConfig -TestConfigFilePath $localTestConfigFilePath
$location = $localTestConfig.location
$testSubscriptionName = $localTestConfig.testSubscription
$testSubscriptionId = $globalTestConfig.Subscriptions.$testSubscriptionName.id
$testResourceGroup = $localTestConfig.testResourceGroup
$whatIfMaxRetry = $globalTestConfig.whatIfMaxRetry
$coreMG = $localTestConfig.coreManagementGroup
$vnetPolicyAssignmentName = $localTestConfig.vnetAssignmentName
$vnetPolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $coreMg, $vnetPolicyAssignmentName

$testManagementGroup = $localTestConfig.testManagementGroup
$diagSettingsPolicyAssignmentName = $localTestConfig.diagSettingsAssignmentName
$diagSettingsPolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $testManagementGroup, $diagSettingsPolicyAssignmentName
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $diagnosticSettingsIdSuffix
$vnetFlowLogApiVersion = '2024-07-01'
$aeVnetFlowLogId = '/subscriptions/{0}/resourceGroups/NetworkWatcherRG/providers/microsoft.network/networkwatchers/networkWatcher_australiaeast/flowlogs/{1}-flowlog' -f $testSubscriptionId, $resourceName
$aseVnetFlowLogId = '/subscriptions/{0}/resourceGroups/NetworkWatcherRG/providers/microsoft.network/networkwatchers/networkWatcher_australiasoutheast/flowlogs/{1}-flowlog' -f $testSubscriptionId, $aseVNetResourceName

$whatIfDeploymentTargetResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubscriptionId, $testResourceGroup
$whatIfSuccessTemplatePath = join-path $PSScriptRoot 'main.good.bicep'
$whatIfFailedTemplatePath = join-path $PSScriptRoot 'main.bad.bicep'


#define violating deny policies
$violatingPolicies = @(
  @{
    policyAssignmentId          = $vnetPolicyAssignmentId
    policyDefinitionReferenceId = 'VNET-001'
  }
  @{
    policyAssignmentId          = $vnetPolicyAssignmentId
    policyDefinitionReferenceId = 'VNET-002'
  }
)

#create test resource group if doesn't exist
Set-AzContext -SubscriptionId $testSubscriptionId
$existingTestRg = Get-AzResourceGroup -Name $testResourceGroup -ErrorAction SilentlyContinue
if (-not $existingTestRg) {
  Write-Verbose "Creating test resource group $testResourceGroup" -Verbose
  New-AzResourceGroup -Name $testResourceGroup -Location $location
}

#define tests
$tests = @()

#DeployIfNotExists Policies
# DS-020 vnet-config-diag-logs
$tests += New-ARTResourceExistenceTestConfig 'DS-058: Diagnostic Settings for VNet Must Be Configured' $diagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-058: Diagnostic Settings Policy Must Be Compliant' $resourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-058'

#VNet Flow logs (Australia East)
$tests += New-ARTPropertyValueTestConfig -testName 'VNET-003: VNet Flow Log must be enabled in Australia East' -resourceId $aeVnetFlowLogId -property 'properties.enabled' -valueType 'boolean' -condition 'equals' -value $true -apiVersion $vnetFlowLogApiVersion
$tests += New-ARTPropertyCountTestConfig -testName 'VNET-003: VNet Flow Log (Australia East) Must Be Configured to use Log Analytics Workspace' -resourceId $aeVnetFlowLogId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.workspaceResourceId' -condition 'equals' -count 1  -apiVersion $vnetFlowLogApiVersion
$tests += New-ARTPropertyValueTestConfig -testName 'VNET-003: VNet Flow Log (Australia East) Traffic Analytics must be enabled' -resourceId $aeVnetFlowLogId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.enabled' -valueType 'boolean' -condition 'equals' -value $true  -apiVersion $vnetFlowLogApiVersion
$tests += New-ARTPolicyStateTestConfig 'VNET-003: VNet Flow Log Policy (Australia East) Must Be Compliant' $resourceId $vnetPolicyAssignmentId 'Compliant' 'VNET-003'

#VNet Flow logs (Australia Southeast)
$tests += New-ARTPropertyValueTestConfig -testName 'VNET-004: VNet Flow Log must be enabled in Australia Southeast' -resourceId $aseVnetFlowLogId -property 'properties.enabled' -valueType 'boolean' -condition 'equals' -value $true -apiVersion $vnetFlowLogApiVersion
$tests += New-ARTPropertyCountTestConfig -testName 'VNET-004: VNet Flow Log (Australia Southeast) Must Be Configured to use Log Analytics Workspace' -resourceId $aseVnetFlowLogId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.workspaceResourceId' -condition 'equals' -count 1  -apiVersion $vnetFlowLogApiVersion
$tests += New-ARTPropertyValueTestConfig -testName 'VNET-004: VNet Flow Log (Australia Southeast) Traffic Analytics must be enabled' -resourceId $aseVnetFlowLogId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.enabled' -valueType 'boolean' -condition 'equals' -value $true  -apiVersion $vnetFlowLogApiVersion
$tests += New-ARTPolicyStateTestConfig 'VNET-004: VNet Flow Log Policy (Australia East) Must Be Compliant' $aseVNetResourceId $vnetPolicyAssignmentId 'Compliant' 'VNET-004'

#Deny policies
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $whatIfSuccessTemplatePath $whatIfDeploymentTargetResourceId 'Succeeded' -maxRetry $whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $whatIfFailedTemplatePath $whatIfDeploymentTargetResourceId 'Failed' $violatingPolicies -maxRetry $whatIfMaxRetry
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
