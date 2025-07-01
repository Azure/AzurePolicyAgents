targetScope = 'subscription'

@description('Location for all resources.')
param location string = deployment().location

@description('Resource group name')
param rgName string = ''

@description('Resource name prefix')
param resourceName string = ''

@description('Model name')
param agentModelName string = 'gpt-4o'

@description('Model version')
param agentModelVersion string = '2024-05-13'

@description('Model deployment name')
param agentModelDeploymentName string = 'gpt-4o'

@description('Agent model SKU name')
param agentModelSkuName string = 'DataZoneStandard'

@description('Model capacity')
param agentModelCapacity int = 150

@description('Add knowledge to the AI Agents')
@allowed([
  'none'
  'groundingWithBing'
  'aiSearch'
])
param addKnowledge string = 'none'

module rg './modules/rg.bicep' = {
  name: 'rg-${location}'
  params: {
    rgName: rgName
    location: location
  }
}

// Deploy Log Analytics workspace
module logAnalyticsWorkspace './modules/logAnalytics.bicep' = {
  name: 'logAnalyticsWorkspace'
  dependsOn: [
    rg
  ]
  scope: resourceGroup(rgName)
  params: {
    location: location
    resourceName: '${resourceName}-logAnalytics'
    skuName: 'PerGB2018'
    retentionInDays: 30
  }
}

// Optionally add Grounding with Bing
module groundingWithBing './modules/bingGrounding.bicep' = if (addKnowledge == 'groundingWithBing') {
  name: 'groundingWithBing'
  scope: resourceGroup(rgName)
  dependsOn: [
    rg
  ]
  params: {
    resourceName: '${resourceName}-bingGrounding'
  }
}

// Deploy Azure AI Agents
module azureAIAgents './modules/azureAIServices.bicep' = {
  name: 'azureAIAgents'
  dependsOn: [
    rg
  ]
  scope: resourceGroup(rgName)
  params: {
    location: location
    resourceName: '${resourceName}-agents'
    modelCapacity: agentModelCapacity
    modelName: agentModelName
    modelVersion: agentModelVersion
    modelSkuName: agentModelSkuName
    modelDeploymentName: agentModelDeploymentName
    logAnaltyicsWorkspaceId: logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
    bingGroundingKey: addKnowledge == 'groundingWithBing' ? groundingWithBing.outputs.bingKeys : ''
    bingGroundingResourceId: addKnowledge == 'groundingWithBing' ? groundingWithBing.outputs.bingResourceId : ''
  }
}

module roleAssignments './modules/roleAssignment.bicep' = {
  name: 'roleAssignments'
  scope: resourceGroup(rgName)
  params: {
    objectId: azureAIAgents.outputs.identityObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/64702f94-c441-49e6-a78b-ef80e0188fee'
  }
}

// Role assignment for the callerId submitting the deployment
module callerIdRoleAssignments './modules/roleAssignment.bicep' = {
  name: 'userRoleAssignments'
  scope: resourceGroup(rgName)
  dependsOn: [
    rg
  ]
  params: {
    objectId: deployer().objectId
    principalType: 'User'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d'
  }
}

// Deployment script to initialize the Policy Agent
module initializeAgentSetup './modules/deploymentScript.bicep' = {
  name: 'initializeAgentProxySetup'
  dependsOn: [
    rg
    roleAssignments
  ]
  scope: resourceGroup(rgName)
  params: {
    location: location
    resourceName: resourceName
  }
}

module umiRoleAssignment './modules/roleAssignment.bicep' = {
  name: 'umiRoleAssignment'
  scope: resourceGroup(rgName)
  params: {
    objectId: initializeAgentSetup.outputs.userAssignedIdentityObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  }
}

// Azure AI Agents Outputs
output agentEndpoint string = azureAIAgents.outputs.agentEndpoint
output agentModelName string = azureAIAgents.outputs.modelName
output agentModelDeploymentName string = azureAIAgents.outputs.modelDeploymentName 
output agentProjectResourceId string = azureAIAgents.outputs.projectResourceId
output userAssignedIdentityObjectId string = initializeAgentSetup.outputs.userAssignedIdentityObjectId

// Shared Infrastructure Outputs
output resourceGroupName string = rgName

// Bing Grounding Outputs
output bingConnectionId string = azureAIAgents.outputs.bingGroundingConnectionId
