metadata itemDisplayName = 'Test Template for Azure Monitor'
metadata description = 'This template deploys the testing resource for azure monitor.'
metadata summary = 'Deploys test azure monitor resources that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.location
var namePrefix = globalConfig.namePrefix
var crossSubActionResourceSubscriptionName = localConfig.crossSubActionResourceSubscription
var crossSubActionResourceSubscription = globalConfig.subscriptions[crossSubActionResourceSubscriptionName]
var crossSubActionResourceSubscriptionId = crossSubActionResourceSubscription.id

// define template specific variables
var serviceShort = 'mon3'
var actionGroupName = 'ag-${namePrefix}-${serviceShort}-01'
var actionGroupShortName = 'agtest03'
//Dummy cross subscription resource Ids. Don't have to be real, they will be used for ARM what-if deployment validation
var dummyCrossSubAutomationAccountId = '/subscriptions/${crossSubActionResourceSubscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.Automation/automationAccounts/automationAccount1'
var dummyCrossSubAutomationAccountWebhookId = '/subscriptions/${crossSubActionResourceSubscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.Automation/automationAccounts/automationAccount1/webhooks/alert1'
var dummyCrossSubFunctionAppId = '/subscriptions/${crossSubActionResourceSubscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.Web/sites/functionApp1'
var dummyCrossSubLogicAppId = '/subscriptions/${crossSubActionResourceSubscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.Logic/workflows/logicApp1'
var dummyCrossSubEventHubId = '/subscriptions/${crossSubActionResourceSubscriptionId}/resourceGroups/rg-${namePrefix}-mon3-01/providers/Microsoft.EventHub/namespaces/eventHub1'
resource actionGroup 'Microsoft.Insights/actionGroups@2024-10-01-preview' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    smsReceivers: [
      {
        name: 'sms1'
        countryCode: '7' //Country code for Russia, should violate policy MON-002
        phoneNumber: '2345678901'
      }
    ]
    emailReceivers: [
      {
        emailAddress: 'test.user1@outlook.com' //violate policy MON-001
        name: 'email1'
        useCommonAlertSchema: true
      }
    ]
    automationRunbookReceivers: [
      {
        name: 'runbook1'
        automationAccountId: dummyCrossSubAutomationAccountId //violate policy MON-003
        webhookResourceId: dummyCrossSubAutomationAccountWebhookId
        runbookName: 'runbookName1'
        useCommonAlertSchema: true
        isGlobalRunbook: false
      }
    ]
    eventHubReceivers: [
      {
        name: 'eventHub1'
        eventHubName: 'eventHub1'
        eventHubNameSpace: dummyCrossSubEventHubId //violate policy MON-004
        subscriptionId: crossSubActionResourceSubscriptionId
        useCommonAlertSchema: true
      }
    ]
    azureFunctionReceivers: [
      {
        name: 'function1'
        functionAppResourceId: dummyCrossSubFunctionAppId //violate policy MON-005
        functionName: 'functionName1'
        httpTriggerUrl: 'https://function1.com'
        useCommonAlertSchema: true
      }
    ]
    logicAppReceivers: [
      {
        name: 'logicApp1'
        resourceId: dummyCrossSubLogicAppId //violate policy MON-006
        useCommonAlertSchema: true
        callbackUrl: 'https://logicApp1.com'
      }
    ]
    webhookReceivers: [
      {
        name: 'webhook1'
        serviceUri: 'http://webhookuri1.com' //violate policy MON-007 and MON-008
        useCommonAlertSchema: true
      }
    ]
  }
}
output name string = actionGroup.name
output resourceId string = actionGroup.id
output location string = actionGroup.location
