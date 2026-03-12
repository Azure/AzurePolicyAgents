using module ../../../ps_modules/AzResourceTest/AzResourceTest.psm1

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').path

#load helper
. $helperFunctionScriptPath

<#
Test cases:
- P-PE-02: AMPLS Private Endpoint is not allowed (Deny)
#>

#variables
$deploymentOutputs = $env:bicepDeploymentOutputs
$deploymentId = $env:bicepDeploymentId
$deploymentTarget = $env:bicepDeploymentTarget
$deploymentScope = $env:bicepDeploymentScope
$outputFilePath = $env:outputFilePath
$outputFormat = $env:outputFormat
$token = $(az account get-access-token --resource 'https://management.azure.com/' | convertfrom-json).accessToken
#Define tests
$testTitle = "Azure Private Endpoint Configuration Test"
$contextTitle = "Private Endpoint Configuration"
$testSuiteName = 'PrivateEndpointTest'

$gitRoot = Get-GitRoot
$globalTestConfigFilePath = join-path $gitRoot 'tests' '.shared' '.config' 'policy_integration_test_config.jsonc'
$localTestConfigFilePath = join-path $PSScriptRoot 'config.json'
$globalTestConfig = getTestConfig -TestConfigFilePath $globalTestConfigFilePath
$localTestConfig = getTestConfig -TestConfigFilePath $localTestConfigFilePath
$testSubscriptionName = $localTestConfig.testSubscription
$testResourceGroup = $localTestConfig.testResourceGroup
$testSubscriptionId = $globalTestConfig.Subscriptions.$testSubscriptionName.id
$vnetResourceGroup = $globalTestConfig.Subscriptions.$testSubscriptionName.networkResourceGroup
$vnetName = $globalTestConfig.Subscriptions.$testSubscriptionName.vNet
$peSubnetName = $globalTestConfig.Subscriptions.$testSubscriptionName.peSubnet
$namePrefix = $globalTestConfig.namePrefix
$location = $localTestConfig.location
$serviceShort = 'pe1'
$amplsName = 'ampls-{0}-{1}-01' -f $namePrefix, $serviceShort
$peName = 'pe-ampls-{0}-{1}-01' -f $namePrefix, $serviceShort
$whatIfMaxRetry = $globalTestConfig.whatIfMaxRetry
$testMG = $localTestConfig.testManagementGroup
$whatIfFailedTemplateAMPLSPath = join-path $PSScriptRoot 'main.bad.ampls.bicep'
$deploymentTargetResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubscriptionId, $testResourceGroup
$peAssignmentName = $localTestConfig.peAssignmentName
$pePolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $testMG, $peAssignmentName
$amplsViolatingPolicies = @(
  @{
    policyAssignmentId          = $pePolicyAssignmentId
    policyDefinitionReferenceId = 'P-PE-02'
    resourceReference           = $peName
    policyEffect                = 'Deny'
  }
)

$subnetId = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/virtualNetworks/{2}/subnets/{3}' -f $testSubscriptionId, $vnetResourceGroup, $vnetName, $peSubnetName
$amplsViolatingResourceContent = @{
  properties = @{
    subnet                        = @{
      id = $subnetId
    }
    privateLinkServiceConnections = @(
      @{
        name       = 'ampls-01'
        properties = @{
          privateLinkServiceId = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Insights/privateLinkScopes/{2}' -f $testSubscriptionId, $testResourceGroup, $amplsName
          groupIds             = @('azuremonitor') # should violate policy P-PE-02: azuremonitor PE is not allowed
        }
      }
    )
  }
}
$amplsViolatingResourceConfig = @{
  resourceName       = $peName
  resourceType       = 'Microsoft.Network/privateEndpoints'
  apiVersion         = '2024-01-01'
  resourceContent    = $($amplsViolatingResourceContent | ConvertTo-Json -Depth 99)
  location           = $location
  includeAuditEffect = $true
}
#define tests
$tests = @()
#$tests += New-ARTWhatIfDeploymentTestConfig -testName 'AMPLS Private Endpoints Policy violating deployment should fail' -token $token -templateFilePath $whatIfFailedTemplateAMPLSPath -deploymentTargetResourceId $whatIfDeploymentTargetResourceId -requiredWhatIfStatus 'Failed' -policyViolation $amplsViolatingPolicies -maxRetry $whatIfMaxRetry
$tests += New-ARTArmPolicyRestrictionTestConfig -testName 'AMPLS Private Endpoints should violate deny policies' -token $token -deploymentTargetResourceId $deploymentTargetResourceId -resourceConfig $amplsViolatingResourceConfig -policyViolation $amplsViolatingPolicies
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
