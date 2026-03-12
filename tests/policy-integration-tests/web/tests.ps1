using module ../../../ps_modules/AzResourceTest/AzResourceTest.psm1

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').path

#load helper
. $helperFunctionScriptPath

<#
Test cases:
- DS-026: Configure Diagnostic Settings for Function App (DeployIfNotExists)
- DS-062: Configure Diagnostic Settings for App Services (DeployIfNotExists)
- PEDNS-006: Configure Private DNS Record for Web App Private Endpoint (DeployIfNotExists)
- PEDNS-015: Configure Private DNS Record for Web App Slots Private Endpoint (DeployIfNotExists)
- WEB-001: App Service and function app slots should only be accessible over HTTPS (Deny)
- WEB-002: App Service and Function apps should only be accessible over HTTPS (Deny)
- WEB-003: Function apps should only use approved identity providers for authentication (Deny)
- WEB-004: Prevent cross-subscription Private Link for App Services and Function Apps (Audit)
- WEB-005: Function apps should route application traffic over the virtual network (Deny)
- WEB-006: App Service and Function apps should route configuration traffic over the virtual network (Deny)
- WEB-007: Function apps should route configuration traffic over the virtual network (Deny)
- WEB-008: Function app slots should route configuration traffic over the virtual network (Deny)
- WEB-009: App Service apps should use a SKU that supports private link (Deny)
- WEB-010: Public network access should be disabled for App Services and Function Apps (Deny)
- WEB-011: Public network access should be disabled for App Service and Function App slots (Deny)
#>

#variables
$deploymentOutputs = $env:deploymentOutputs
$deploymentId = $env:deploymentId
$deploymentScope = $env:deploymentScope
$outputFilePath = $env:outputFilePath
$outputFormat = $env:outputFormat
$appServicesApiVersion = '2024-04-01'
#Parse deployment outputs
Write-Verbose "Deployment Outputs: $deploymentOutputs" -Verbose
$deploymentOutputsJson = $deploymentOutputs | ConvertFrom-Json -Depth 99
$functionAppResourceId = $deploymentOutputsJson.resourceId.value
$functionAppConfigResourceId = '{0}/config/web' -f $functionAppResourceId
$crossSubPeWebAppResourceId = $deploymentOutputsJson.crossSubPeWebAppResourceId.value
$webAppResourceId = $deploymentOutputsJson.webAppResourceId.value
$functionAppSlotResourceId = $deploymentOutputsJson.functionAppSlotResourceId.value
$functionAppSlotConfigResourceId = '{0}/config/web' -f $functionAppSlotResourceId
$webAppSlotResourceId = $deploymentOutputsJson.webAppSlotResourceId.value
$functionAppPrivateEndpointName = $deploymentOutputsJson.functionAppPrivateEndpointName.value
$functionAppPrivateEndpoints = $deploymentOutputsJson.functionAppPrivateEndpoints
$functionAppPrivateEndpoint = $functionAppPrivateEndpoints.value | where-object { $_.name -ieq $functionAppPrivateEndpointName }
$functionAppPrivateEndpointResourceId = $functionAppPrivateEndpoint.resourceId
$functionAppPrivateEndpointPrivateDNSZoneGroupId = '{0}/privateDnsZoneGroups/deployedByPolicy' -f $functionAppPrivateEndpointResourceId

$privateEndpointConnectionResourceId = $(getResourceViaARMAPI -resourceId "$webAppResourceId/privateEndpointConnections" -apiVersion $appServicesApiVersion).value[0].id
$crossSubPePrivateEndpointConnectionResourceId = $(getResourceViaARMAPI -resourceId "$crossSubPeWebAppResourceId/privateEndpointConnections" -apiVersion $appServicesApiVersion).value[0].id

$webAppPrivateEndpointName = $deploymentOutputsJson.webAppPrivateEndpointName.value
$webAppPrivateEndpoints = $deploymentOutputsJson.webAppPrivateEndpoints
$webAppPrivateEndpoint = $webAppPrivateEndpoints.value | where-object { $_.name -ieq $webAppPrivateEndpointName }
$webAppPrivateEndpointResourceId = $webAppPrivateEndpoint.resourceId
$webAppPrivateEndpointPrivateDNSZoneGroupId = '{0}/privateDnsZoneGroups/deployedByPolicy' -f $webAppPrivateEndpointResourceId
$webAppSlotPrivateEndpointResourceId = $deploymentOutputsJson.webAppSlotPrivateEndpointResourceId.value
$webAppSlotPrivateEndpointPrivateDNSZoneGroupId = '{0}/privateDnsZoneGroups/deployedByPolicy' -f $webAppSlotPrivateEndpointResourceId
$diagnosticSettingsIdSuffix = '/providers/microsoft.insights/diagnosticSettings/setByPolicy'
$diagnosticSettingsAPIVersion = '2021-05-01-preview'
$privateDNSZoneGroupAPIVersion = '2024-01-01'
$appServicesAPIVersion = '2024-04-01'

#Define tests
$testTitle = "App Services Configuration Test"
$contextTitle = "AppServices Configuration"
$testSuiteName = 'AppServicesTest'

$gitRoot = Get-GitRoot
$globalTestConfigFilePath = join-path $gitRoot 'tests' '.shared' '.config' 'policy_integration_test_config.jsonc'
$localTestConfigFilePath = join-path $PSScriptRoot 'config.json'
$globalTestConfig = getTestConfig -TestConfigFilePath $globalTestConfigFilePath
$localTestConfig = getTestConfig -TestConfigFilePath $localTestConfigFilePath
$location = $localTestConfig.location
$testSubscriptionName = $localTestConfig.testSubscription
$testResourceGroup = $localTestConfig.testResourceGroup
$testSubscriptionId = $globalTestConfig.Subscriptions.$testSubscriptionName.id
$whatIfMaxRetry = $globalTestConfig.whatIfMaxRetry
$coreMG = $localTestConfig.coreManagementGroup
$appServicesPolicyAssignmentName = $localTestConfig.AppServicesAssignmentName
$appServicesPolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $coreMg, $appServicesPolicyAssignmentName
$testManagementGroup = $localTestConfig.testManagementGroup
$diagSettingsPolicyAssignmentName = $localTestConfig.diagSettingsAssignmentName
$diagSettingsPolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $testManagementGroup, $diagSettingsPolicyAssignmentName
$whatIfDeploymentTargetResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubscriptionId, $testResourceGroup
$diagnosticSettingsIdSuffix = '/providers/microsoft.insights/diagnosticSettings/setByPolicy'
$diagnosticSettingsAPIVersion = '2021-05-01-preview'
$functionAppDiagnosticSettingsId = "{0}{1}" -f $functionAppResourceId, $diagnosticSettingsIdSuffix
$AppServicesDiagnosticSettingsId = "{0}{1}" -f $webAppResourceId, $diagnosticSettingsIdSuffix
$CrossSubPeAppServicesDiagnosticSettingsId = "{0}{1}" -f $crossSubPeWebAppResourceId, $diagnosticSettingsIdSuffix
$whatIfSuccessTemplatePath = join-path $PSScriptRoot 'main.good.bicep'
$whatIfFailedTemplatePath = join-path $PSScriptRoot 'main.bad.bicep'

$violatingPolicies = @(
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-001'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-002'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-003'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-005'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-006'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-007'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-008'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-009'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-010'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-011'
  }
)
#create test resource groups if doesn't exist
Set-AzContext -SubscriptionId $testSubscriptionId
$existingTestRg = Get-AzResourceGroup -Name $testResourceGroup -ErrorAction SilentlyContinue
if (-not $existingTestRg) {
  Write-Verbose "Creating test resource group $testResourceGroup" -Verbose
  New-AzResourceGroup -Name $testResourceGroup -Location $location
}

#define tests
$tests = @()

#Audit / AuditIfNotExists Policies

$tests += New-ARTPolicyStateTestConfig 'WEB-004: Azure App Service and Function Apps with Cross subscription PE must be non-compliant with policy Prevent cross-subscription Private Link for Azure App Service' $crossSubPePrivateEndpointConnectionResourceId $appServicesPolicyAssignmentId 'NonCompliant' 'WEB-022'

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'DS-062: Premium SKU App Services Diagnostic Settings Must Be Configured' $AppServicesDiagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-062: Premium SKU App Services Diagnostic Settings Policy Must Be Compliant' $webAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-062'

$tests += New-ARTResourceExistenceTestConfig 'DS-062: Standard SKU App Services Diagnostic Settings Must Be Configured' $CrossSubPeAppServicesDiagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-062: Standard SKU App Services Diagnostic Settings Policy Must Be Compliant' $crossSubPeWebAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-062'

$tests += New-ARTResourceExistenceTestConfig 'DS-062: Premium SKU App Services Diagnostic Settings Must Be Configured' $AppServicesDiagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-062: Premium SKU App Services Diagnostic Settings Policy Must Be Compliant' $webAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-062'

$tests += New-ARTResourceExistenceTestConfig 'DS-062: Standard SKU App Services Diagnostic Settings Must Be Configured' $CrossSubPeAppServicesDiagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-062: Standard SKU App Services Diagnostic Settings Policy Must Be Compliant' $crossSubPeWebAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-062'

$tests += New-ARTResourceExistenceTestConfig 'DS-026: Function App Diagnostic Settings Must Be Configured' $functionAppDiagnosticSettingsId 'exists' $diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-026: Function App Diagnostic Settings Policy Must Be Compliant' $functionAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-026'

$tests += New-ARTResourceExistenceTestConfig 'PEDNS-006: Private DNS Record for Function App PE must exist' $functionAppPrivateEndpointPrivateDNSZoneGroupId 'exists' $privateDNSZoneGroupAPIVersion
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-006: Private DNS Record for Web App PE must exist' $webAppPrivateEndpointPrivateDNSZoneGroupId 'exists' $privateDNSZoneGroupAPIVersion
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-015: Private DNS Record for Web App Slot PE must exist' $webAppSlotPrivateEndpointPrivateDNSZoneGroupId 'exists' $privateDNSZoneGroupAPIVersion
$tests += New-ARTPropertyValueTestConfig -testName 'WEB-005: App Services and Function app slot must use the latest TLS version of 1.3' -resourceId $functionAppSlotConfigResourceId -valueType 'string' -property 'properties.minTlsVersion' -condition 'equals' -value '1.3' -apiVersion $appServicesAPIVersion
$tests += New-ARTPropertyValueTestConfig -testName 'WEB-016: App Services and Function app slot must have Remote Debugging disabled' -resourceId $functionAppSlotConfigResourceId -valueType 'boolean' -property 'properties.remoteDebuggingEnabled' -condition 'equals' -value $false -apiVersion $appServicesAPIVersion
$tests += New-ARTPropertyValueTestConfig -testName 'WEB-021: App Services and Function app must use the latest TLS version of 1.3' -resourceId $functionAppConfigResourceId -valueType 'string' -property 'properties.minTlsVersion' -condition 'equals' -value '1.3' -apiVersion $appServicesAPIVersion

#Deny policies
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Policy violating deployment should fail' -templateFilePath $whatIfFailedTemplatePath -deploymentTargetResourceId $whatIfDeploymentTargetResourceId -requiredWhatIfStatus 'Failed' -policyViolation $violatingPolicies -bicepModuleSubscriptionId $vmlSubscriptionId -maxRetry $whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Policy abiding deployment should succeed' $whatIfSuccessTemplatePath -deploymentTargetResourceId $whatIfDeploymentTargetResourceId -requiredWhatIfStatus 'Succeeded' -maxRetry $whatIfMaxRetry

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
