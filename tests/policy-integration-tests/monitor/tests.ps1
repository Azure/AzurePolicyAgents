using module ../../../infra/pwsh/AzResourceTest/AzResourceTest.psd1

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').path

#load helper
. $helperFunctionScriptPath

#variables
$outputFilePath = $env:outputFilePath ? $env:outputFilePath : $(join-path $PSScriptRoot 'output.xml')
$outputFormat = $env:outputFormat ? $env:outputFormat : 'NUnitXml'
#Parse deployment outputs

$token = $(az account get-access-token --resource 'https://management.azure.com/' | convertfrom-json).accessToken

$testTitle = "Azure Monitor Configuration Test"
$contextTitle = "Monitor Configuration"
$testSuiteName = 'AzureMonitorTest'

$gitRoot = Get-GitRoot
$globalTestConfigFilePath = join-path $gitRoot 'tests' '.shared' '.config' 'policy_integration_test_config.jsonc'
$localTestConfigFilePath = join-path $PSScriptRoot 'config.json'
$globalTestConfig = getTestConfig -TestConfigFilePath $globalTestConfigFilePath
$localTestConfig = getTestConfig -TestConfigFilePath $localTestConfigFilePath

$testSubscriptionName = $localTestConfig.testSubscription
$testSubscriptionId = $globalTestConfig.Subscriptions.$testSubscriptionName.id
$testResourceGroup = $localTestConfig.testResourceGroup
$whatIfMaxRetry = $globalTestConfig.whatIfMaxRetry
$monitorPolicyAssignmentName = $localTestConfig.monitorAssignmentName
$testMG = $localTestConfig.testManagementGroup
$monitorAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $testMG, $monitorPolicyAssignmentName
$deploymentTargetResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubscriptionId, $testResourceGroup
$whatIfSuccessTemplatePath = join-path $PSScriptRoot 'main.good.bicep'
$whatIfFailedTemplatePath = join-path $PSScriptRoot 'main.bad.bicep'
$actionGroupName = 'ag01'

$actionGroupViolatingResourceContent = @{
  properties = @{
    smsReceivers               = @(
      @{
        countryCode = '1' #violate policy MON-002
        phoneNumber = '2345678901' #violate policy MON-002
      }
    )
    emailReceivers             = @(
      @{
        emailAddress = 'test.user1@outlook.com' #violate policy MON-001
      }
    )
    automationRunbookReceivers = @(
      @{
        automationAccountId = '/subscriptions/62740b7e-8b53-4411-a353-14e023983d78/resourceGroups/rg-mon3-01/providers/Microsoft.Automation/automationAccounts/automationAccount1/webhooks/alert1' #violate policy MON-003
      }
    )
    eventHubReceivers          = @(
      @{
        eventHubNameSpace = '/subscriptions/62740b7e-8b53-4411-a353-14e023983d78/resourceGroups/rg-mon3-01/providers/Microsoft.EventHub/namespaces/eventHub1' #violate policy MON-004
      }
    )
    azureFunctionReceivers     = @(
      @{
        functionAppResourceId = '/subscriptions/62740b7e-8b53-4411-a353-14e023983d78/resourceGroups/rg-mon3-01/providers/Microsoft.Web/sites/functionApp1' #violate policy MON-005
      }
    )
    logicAppReceivers          = @(
      @{
        resourceId = '/subscriptions/62740b7e-8b53-4411-a353-14e023983d78/resourceGroups/rg-mon3-01/providers/Microsoft.Logic/workflows/logicApp1' #violate policy MON-006
      }
    )
    webhookReceivers           = @(
      @{
        serviceUri = 'http://webhookuri1.com' #violate policy MON-007 and MON-008
      }
    )
  }
} | ConvertTo-Json -Depth 99
Write-Output "Action Group Violating Resource Content: `n $actionGroupViolatingResourceContent"
$actionGroupViolatingResourceConfig = @{
  resourceName       = $actionGroupName
  resourceType       = 'Microsoft.Insights/actionGroups'
  apiVersion         = '2024-10-01-preview'
  resourceContent    = $actionGroupViolatingResourceContent
  location           = 'global'
  includeAuditEffect = $true
}
$violatingPolicies = @(
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-001'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-002'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-003'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-004'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-005'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-006'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-007'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-008'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
)

#define tests
$tests = @()



#$tests += New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $token $whatIfSuccessTemplatePath $deploymentTargetResourceId 'Succeeded' -maxRetry $whatIfMaxRetry
#$tests += New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $token $whatIfFailedTemplatePath $deploymentTargetResourceId 'Failed' $violatingPolicies -maxRetry $whatIfMaxRetry
$tests += New-ARTArmPolicyRestrictionTestConfig -testName 'Action Group should violate deny policies' -token $token -deploymentTargetResourceId $deploymentTargetResourceId -resourceConfig $actionGroupViolatingResourceConfig -policyViolation $violatingPolicies
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
