targetScope = 'subscription'

@description('Location for all resources.')
param location string = deployment().location

@description('Type of setup to deploy')
@allowed([
  'azureAIAgents'
  'azureOpenAIAssistants'
])
param setupType string = 'azureAIAgents'

@description('Resource group name')
param rgName string = ''

@description('Resource name prefix')
param resourceName string = ''

@description('Instructions for the proxy agent')
param proxyAgentInstructions string = 'You are a proxy AI Agent that interacts with specialized AI Agents to solve complex tasks. Always ensure the agents respond and complete their runs before returning an answer. If you need to instantiate any new agents, always use model gpt-4o.'

@description('Agent name')
param proxyAgentName string = 'MetroProxyAgent'

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

@description('Optionally add sample scenarios')
@allowed([
  'none'
  'finance'
  'customerSupport'
])
param sampleScenario string = 'none'

var openApiSpecs = [
  'https://gist.githubusercontent.com/krnese/2d2a37b6241a6493cbe3fddbc89a9f47/raw/274daddec2cbb20cb3e513c8d0ce257bbb39c62b/swagger.json'
  'https://gist.githubusercontent.com/krnese/bdc6d6f76e927ec2cf54626aab07a5cf/raw/7bd665b2e3415df7924169b03ae457d3d0bd174f/aiAgentSwagger.json'
]

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
module groundingWithBing './modules/bingGrounding.bicep' = if (addKnowledge == 'groundingWithBing' && sampleScenario != 'none') {
  name: 'groundingWithBing'
  scope: resourceGroup(rgName)
  dependsOn: [
    rg
  ]
  params: {
    resourceName: '${resourceName}-bingGrounding'
  }
}

// Only deploy the explicit Azure OpenAI resource if the setupType is set to 'azureOpenAIAssistants'. This will act as the backend AI Agents for the Proxy Agent
module azureOpenAI './modules/azureOpenAI.bicep' = if (setupType == 'azureOpenAIAssistants') {
  name: 'azureOpenAI'
  dependsOn: [
    rg
  ]
  scope: resourceGroup(rgName)
  params: {
    location: location
    resourceName: resourceName
    logAnaltyicsWorkspaceId: logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
  }
}

// Only deploy the Azure AI Agents if the setupType is set to 'azureAIAgents'. This will act as the backend AI Agents for the Proxy Agent
module azureAIAgents './modules/azureAIServices.bicep' = if (setupType == 'azureAIAgents') {
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

// Deployment script to initialize the Proxy Agent with instruction and OpenAPI for Azure AI Agents
module initializeAgentProxySetup './modules/deploymentScript.bicep' = {
  name: 'initializeAgentProxySetup'
  dependsOn: [
    rg
    roleAssignments
  ]
  scope: resourceGroup(rgName)
  params: {
    location: location
    resourceName: resourceName
    azAIAgentUri: setupType == 'azureAIAgents' ? azureAIAgents.outputs.agentEndpoint : azureOpenAI.outputs.endpoint
    openApiDefinitionUri: setupType == 'azureOpenAIAssistants' ? openApiSpecs[0] : openApiSpecs[1]
    modelDeploymentName: azureAIAgents.outputs.modelDeploymentName
    azAIProxyInstructions: proxyAgentInstructions
    azAIProxyUri: azureAIAgents.outputs.agentEndpoint
    azAgentName: proxyAgentName
    setupType: setupType
  }
}

// Conditionally add sample scenarios
module sampleScenarios './modules/sampleSetup.bicep' = if (sampleScenario != 'none' && setupType == 'azureAIAgents') {
  name: 'initializeSampleScenarios'
  dependsOn: [
    rg
    roleAssignments
  ]
  scope: resourceGroup(rgName)
  params: {
    location: location
    azAIAgentUri: setupType == 'azureAIAgents' ? azureAIAgents.outputs.agentEndpoint : azureOpenAI.outputs.endpoint
    modelDeploymentName: azureAIAgents.outputs.modelDeploymentName
    sampleScenario: sampleScenario
    userAssignedIdentityId: initializeAgentProxySetup.outputs.userAssignedIdentityId
  }
}

// Azure AI Agents Outputs
output agentEndpoint string = setupType == 'azureAIAgents' ? azureAIAgents.outputs.agentEndpoint : ''
output agentModelName string = setupType == 'azureAIAgents' ? azureAIAgents.outputs.modelName : ''
output agentModelDeploymentName string = setupType == 'azureAIAgents' ? azureAIAgents.outputs.modelDeploymentName : ''
output agentProjectResourceId string = setupType == 'azureAIAgents' ? azureAIAgents.outputs.projectResourceId : ''

// Azure OpenAI Assistants Outputs
output openAIEndpoint string = setupType == 'azureOpenAIAssistants' ? azureOpenAI.outputs.endpoint : ''
output openAIModelName string = setupType == 'azureOpenAIAssistants' ? azureOpenAI.outputs.modelName : ''
output openAIModelDeploymentName string = setupType == 'azureOpenAIAssistants'
  ? azureOpenAI.outputs.modelDeploymentName
  : ''
