targetScope = 'resourceGroup'

param location string = resourceGroup().location
param userAssignedIdentityId string = ''
param azAIAgentUri string
param modelDeploymentName string = 'gpt-4o'
param sampleScenario string = 'policy'

var scriptSampleScenario = sampleScenario == 'policy' ? loadTextContent('../scriptContent/proxyToAgents.ps1') : ''

resource initialize 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'initialize-${sampleScenario}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '5.8'
    retentionInterval: 'PT1H'
    scriptContent: scriptSampleScenario
    cleanupPreference: 'OnSuccess'
    timeout: 'PT1H'
    arguments: '-modelDeploymentName "${modelDeploymentName}" -azAIAgentUri "${azAIAgentUri}" -azAgentName'
  }
}

output arguments string = initialize.properties.arguments
