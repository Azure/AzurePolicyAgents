targetScope = 'resourceGroup'

param location string = resourceGroup().location
param resourceName string = 'depScript'
param openApiDefinitionUri string
param azAIProxyUri string
param azAIAgentUri string
param azAIProxyInstructions string = 'You are a proxy AI Agent that interacts with specialized AI Agents to solve comlpex tasks. Always ensure the agents respons and complete their runs before returning an answer.'
param azAgentName string = 'TestProxyAgent'
param modelDeploymentName string = 'gpt-4o'
param setupType string = ''

var scriptSetupType = setupType == 'azureAIAgents'
  ? loadTextContent('../scriptContent/proxyToAgents.ps1')
  : setupType == 'azureOpenAIAssistants' ? loadTextContent('../scriptContent/proxyToAssistantsAPI.ps1') : ''

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${resourceName}-uai'
  location: location
}

module roleAssignmentAIAgents 'roleAssignment.bicep' = {
  name: 'roleAssignmentAIAgents'
  scope: resourceGroup()
  params: {
    objectId: userAssignedIdentity.properties.principalId
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d'
    principalType: 'ServicePrincipal'
  }
}

resource initialize 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'initialize-${setupType}'
  location: location
  kind: 'AzurePowerShell'
  dependsOn: [
    roleAssignmentAIAgents
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '5.8'
    retentionInterval: 'PT1H'
    scriptContent: scriptSetupType
    cleanupPreference: 'OnSuccess'
    timeout: 'PT1H'
    arguments: '-modelDeploymentName "${modelDeploymentName}" -azAIProxyInstructions \'${azAIProxyInstructions}\' -azAIProxyUri "${azAIProxyUri}" -openApiDefinitionUri "${openApiDefinitionUri}" -azAIAgentUri "${azAIAgentUri}" -azAgentName "${azAgentName}" -tenantId "${subscription().tenantId}"'
  }
}

output arguments string = initialize.properties.arguments
output userAssignedIdentityId string = userAssignedIdentity.id
