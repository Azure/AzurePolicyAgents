targetScope = 'resourceGroup'

param location string = resourceGroup().location
param resourceName string = 'depScript'
// param azAIAgentUri string
// param modelDeploymentName string = 'gpt-4.1'
// param scriptContent string = loadTextContent('../scriptContent/azurePolicyAgent.ps1')


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

// resource initialize 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   name: 'initialize-azurePolicyAgents'
//   location: location
//   kind: 'AzurePowerShell'
//   dependsOn: [
//     roleAssignmentAIAgents
//   ]
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${userAssignedIdentity.id}': {}
//     }
//   }
//   properties: {
//     azPowerShellVersion: '7.4'
//     retentionInterval: 'PT1H'
//     scriptContent: scriptContent
//     cleanupPreference: 'OnSuccess'
//     timeout: 'PT1H'
//     arguments: '-ModelDeploymentName "${modelDeploymentName}" -AIAgentEndpoint "${azAIAgentUri}"'
//   }
// }

// output arguments string = initialize.properties.arguments
output userAssignedIdentityId string = userAssignedIdentity.id
output userAssignedClientId string = userAssignedIdentity.properties.clientId
output userAssignedIdentityObjectId string = userAssignedIdentity.properties.principalId
// output agentId string = initialize.properties.outputs.agentId
// output agentName string = initialize.properties.outputs.agentName
// output deploymentStatus string = initialize.properties.outputs.status
// output deploymentTimestamp string = initialize.properties.outputs.timestamp

output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId
