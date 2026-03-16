metadata itemDisplayName = 'Test Template for Azure Monitor'
metadata description = 'This template deploys the testing resource for azure monitor.'
metadata summary = 'Deploys test azure monitor resources that should comply with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')

var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'mon3'
var actionGroupName = 'ag-${namePrefix}-${serviceShort}-01'
var actionGroupShortName = 'agtest02'
//Dummy cross subscription resource Ids. Don't have to be real, they will be used for ARM what-if deployment validation
var dummyAutomationAccountId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.Automation/automationAccounts/automationAccount1'
var dummyAutomationAccountWebhookId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.Automation/automationAccounts/automationAccount1/webhooks/alert1'
var dummyFunctionAppId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.Web/sites/functionApp1'
var dummyLogicAppId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.Logic/workflows/logicApp1'
var dummyEventHubId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.EventHub/namespaces/eventHub1'
resource actionGroup 'Microsoft.Insights/actionGroups@2024-10-01-preview' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    smsReceivers: [
      {
        name: 'sms1'
        countryCode: '61' //comply with policy MON-002
        phoneNumber: '491570006' //comply with policy MON-002
      }
    ]
    emailReceivers: [
      {
        emailAddress: 'test.user1@contoso.com' //comply with policy MON-001
        name: 'email1'
        useCommonAlertSchema: true
      }
    ]
    automationRunbookReceivers: [
      {
        name: 'runbook1'
        automationAccountId: dummyAutomationAccountId //comply with policy MON-003
        webhookResourceId: dummyAutomationAccountWebhookId
        runbookName: 'runbookName1'
        useCommonAlertSchema: true
        isGlobalRunbook: false
      }
    ]
    eventHubReceivers: [
      {
        name: 'eventHub1'
        eventHubName: 'eventHub1'
        eventHubNameSpace: dummyEventHubId //comply with policy MON-004
        subscriptionId: subscription().id
        useCommonAlertSchema: true
      }
    ]
    azureFunctionReceivers: [
      {
        name: 'function1'
        functionAppResourceId: dummyFunctionAppId //comply with policy MON-005
        functionName: 'functionName1'
        httpTriggerUrl: 'https://function1.com'
        useCommonAlertSchema: true
      }
    ]
    logicAppReceivers: [
      {
        name: 'logicApp1'
        resourceId: dummyLogicAppId //comply with policy MON-006
        useCommonAlertSchema: true
        callbackUrl: 'https://logicApp1.com'
      }
    ]
    webhookReceivers: [
      {
        name: 'webhook1'
        serviceUri: 'https://webhookuri.com' //comply with policy MON-007 and MON-008
        useCommonAlertSchema: true
      }
    ]
  }
}
output name string = actionGroup.name
output resourceId string = actionGroup.id
output location string = actionGroup.location
