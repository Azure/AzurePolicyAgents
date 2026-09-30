targetScope = 'subscription'

@description('Location for all resources.')
param location string = deployment().location

@description('Resource group name')
param rgName string = ''

@description('Resource name prefix')
param resourceName string = ''

@description('Model name')
param agentModelName string = 'gpt-5.4'

@description('Model version')
param agentModelVersion string = '2026-03-05'

@description('Model deployment name')
param agentModelDeploymentName string = 'gpt-5.4'

@description('Agent model SKU name')
param agentModelSkuName string = 'DataZoneStandard'

@description('Model capacity (TPM - Tokens Per Minute). Recommended: 500+ for parallel processing, 150 for basic usage.')
@minValue(10)
@maxValue(1000)
param agentModelCapacity int = 500

@description('Add knowledge to the AI Agents')
@allowed([
  'none'
  'groundingWithBing'
])
param addKnowledge string = 'none'

@description('Principal type of the deployer. Use User for interactive deployments, ServicePrincipal for CI/CD pipelines.')
@allowed([
  'User'
  'ServicePrincipal'
])
param deployerPrincipalType string = 'User'

@description('GitHub organisation name')
param githubOrg string

@description('GitHub repository name (e.g. azure-policy-agents)')
param githubRepo string

@description('GitHub Actions environment name used for federated credential subject (e.g. dev)')
param githubEnvironment string

@description('Tags applied to the resource group')
param tags object = {}

module rg 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: 'rg-${location}'
  params: {
    name: rgName
    location: location
    tags: tags
  }
}

// Deploy Log Analytics workspace
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.11.2' = {
  name: 'logAnalyticsWorkspace'
  dependsOn: [
    rg
  ]
  scope: resourceGroup(rgName)
  params: {
    name: '${resourceName}-logAnalytics'
    location: location
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

// Deploy Application Insights linked to the Log Analytics workspace
module appInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: 'appInsights'
  scope: resourceGroup(rgName)
  params: {
    name: '${resourceName}-appi'
    location: location
    workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
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
    skuName: 'F1'  // Try free tier for partner subscriptions
  }
}

// Single Azure AI Services for all 4 specialized policy agents
module singlePolicyAgentFoundry './modules/azureAIServices.bicep' = {
  name: 'singlePolicyAgentFoundry'
  dependsOn: [
    rg
  ]
  scope: resourceGroup(rgName)
  params: {
    location: location
    resourceName: resourceName
    modelCapacity: agentModelCapacity
    modelName: agentModelName
    modelVersion: agentModelVersion
    modelSkuName: agentModelSkuName
    modelDeploymentName: agentModelDeploymentName
    logAnaltyicsWorkspaceId: logAnalyticsWorkspace.outputs.resourceId
    bingGroundingKey: addKnowledge == 'groundingWithBing' ? groundingWithBing.?outputs.?bingKeys ?? '' : ''
    bingGroundingResourceId: addKnowledge == 'groundingWithBing' ? groundingWithBing.?outputs.?bingResourceId ?? '' : ''
    appInsightsId: appInsights.outputs.resourceId
    appInsightsConnectionString: appInsights.outputs.connectionString
  }
}

// All agents will be deployed in the single foundry above

// Single foundry role assignment for all agents
module singleFoundryRoleAssignments 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'singleFoundryRoleAssignments'
  scope: resourceGroup(rgName)
  params: {
    principalId: singlePolicyAgentFoundry.outputs.identityObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/64702f94-c441-49e6-a78b-ef80e0188fee'
  }
}

// Role assignment for the callerId submitting the deployment
module callerIdRoleAssignments 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'userRoleAssignments'
  scope: resourceGroup(rgName)
  dependsOn: [
    rg
  ]
  params: {
    principalId: deployer().objectId
    principalType: deployerPrincipalType
    roleDefinitionIdOrName: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d'
  }
}

// User-assigned identity federated to GitHub Actions, used to run the policy test pipeline
module githubActionsUmi 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: '${resourceName}-uai'
  dependsOn: [
    rg
  ]
  scope: resourceGroup(rgName)
  params: {
    name: '${resourceName}-uai'
    location: location
    federatedIdentityCredentials: [
      {
        name: 'federatedCredential'
        audiences: [
          'api://AzureADTokenExchange'
        ]
        issuer: 'https://token.actions.githubusercontent.com'
        subject: 'repo:${githubOrg}/${githubRepo}:environment:${githubEnvironment}'
      }
    ]
  }
}

// Grants the UMI Contributor over the resource group so it can create the AI Agents resources
module roleAssignmentAIAgents 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'roleAssignmentAIAgents'
  scope: resourceGroup(rgName)
  params: {
    principalId: githubActionsUmi.outputs.principalId
    roleDefinitionIdOrName: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d'
    principalType: 'ServicePrincipal'
  }
}

// Contributor - required to deploy resources for policy testing
module umiRoleAssignmentContributor 'br/public:avm/res/authorization/role-assignment/sub-scope:0.1.1' = {
  name: 'umiRoleAssignmentContributor'
  scope: subscription()
  params: {
    principalId: githubActionsUmi.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  }
}

// Resource Policy Contributor - required to create/update/delete policy definitions and assignments
module umiRoleAssignmentResourcePolicyContributor 'br/public:avm/res/authorization/role-assignment/sub-scope:0.1.1' = {
  name: 'umiRoleAssignmentResourcePolicyContributor'
  scope: subscription()
  params: {
    principalId: githubActionsUmi.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/36243c78-bf99-498c-9df9-86d9f8d28608'
  }
}

// Policy Insights Data Writer - required to write policy state and compliance data
module umiRoleAssignmentPolicyInsightsDataWriter 'br/public:avm/res/authorization/role-assignment/sub-scope:0.1.1' = {
  name: 'umiRoleAssignmentPolicyInsightsDataWriter'
  scope: subscription()
  params: {
    principalId: githubActionsUmi.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/66bb4e9e-b016-4a94-8249-4c0511c2be84'
  }
}

// Role Based Access Control Administrator - required so DINE/modify policy tests can
// assign roles to the policy assignment managed identities (az policy assignment create
// --assign-identity and the roleDefinitionIds loop both call roleAssignments/write).
// This is the least-privilege alternative to Owner/User Access Administrator: it can grant
// Contributor and the diagnostic/monitoring roles the test policies use, but not the
// privileged Owner/User Access Administrator/RBAC Administrator roles.
module umiRoleAssignmentRbacAdministrator 'br/public:avm/res/authorization/role-assignment/sub-scope:0.1.1' = {
  name: 'umiRoleAssignmentRbacAdministrator'
  scope: subscription()
  params: {
    principalId: githubActionsUmi.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168'
  }
}

// Grant the GitHub Actions UMI the Azure AI Developer role on the AI Services resource group.
// This data-plane role is required for the Agents API (Get-MetroAIAgent, New-MetroAIConversation etc.)
// Subscription-scoped management roles (Contributor, RBAC Administrator) do NOT cover
// Cognitive Services / AI Foundry data-plane operations.
module umiAIFoundryRoleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'umiAIFoundryRoleAssignment'
  scope: resourceGroup(rgName)
  params: {
    principalId: githubActionsUmi.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionIdOrName: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/64702f94-c441-49e6-a78b-ef80e0188fee'
  }
}

// Single Foundry Outputs - All 4 specialized agents use the same endpoint
output agentEndpoint string = singlePolicyAgentFoundry.outputs.agentEndpoint
output projectResourceId string = singlePolicyAgentFoundry.outputs.projectResourceId
output modelName string = singlePolicyAgentFoundry.outputs.modelName
output modelDeploymentName string = singlePolicyAgentFoundry.outputs.modelDeploymentName
output aiHubName string = singlePolicyAgentFoundry.outputs.aiHubName
output aiProjectName string = singlePolicyAgentFoundry.outputs.aiProjectName
output userAssignedIdentityObjectId string = githubActionsUmi.outputs.principalId

// Shared Infrastructure Outputs
output resourceGroupName string = rgName

// Application Insights outputs
output appInsightsName string = appInsights.outputs.name
output appInsightsId string = appInsights.outputs.resourceId

// Shared Infrastructure Outputs for GitHub Actions
output azureClientId string = githubActionsUmi.outputs.clientId
output azureTenantId string = subscription().tenantId
output azureSubscriptionId string = subscription().subscriptionId

// Model deployment information (shared across all agents)
output agentModelDeploymentName string = agentModelDeploymentName
