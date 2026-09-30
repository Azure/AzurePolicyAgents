targetScope = 'resourceGroup'

param location string = resourceGroup().location

param resourceName string = 'knff'

param modelDeploymentName string = 'gpt-5.4'

param modelSkuName string = 'DataZoneStandard'

param modelCapacity int = 20

param modelName string = 'gpt-5.4'

param modelVersion string = '2024-11-20'

param skuName string = 'S0'

param logAnaltyicsWorkspaceId string = ''

@secure()
param bingGroundingKey string = ''

param bingGroundingResourceId string = ''

param appInsightsId string = ''

@secure()
param appInsightsConnectionString string = ''

// required roleDefinitions for RBAC'ing the AI project to the AI services
var roleDefinitions = [
  'a97b65f3-24c7-4388-baec-2e87135dc908'
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
]

resource aiServices 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: '${resourceName}-ais'
  location: location
  sku: {
    name: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  properties: {
    allowProjectManagement: true
    customSubDomainName: '${resourceName}-ais'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    restrictOutboundNetworkAccess: false
  }
}

resource aiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  name: modelDeploymentName
  parent: aiServices

  sku: {
    capacity: modelCapacity
    name: modelSkuName
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-06-01' = {
   name: '${resourceName}-accountCapabilityHost'
   parent: aiServices
   properties: {
     capabilityHostKind: 'Agents'
   }
   dependsOn: [
     aiDeployment
   ]
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  name: '${resourceName}-project'
  parent: aiServices
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: '${resourceName} AI Project'
    displayName: '${resourceName} AI Project'
  }
  dependsOn: [
    accountCapabilityHost
  ]
}

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-06-01' = {
  name: '${resourceName}-projectCapabilityHost'
  parent: project
  properties: {}
  dependsOn: [
    accountCapabilityHost
  ]
}

resource groundingWithBingConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = if (!empty(bingGroundingKey) && !empty(bingGroundingResourceId)) {
  name: '${resourceName}-bing-grounding'
  parent: aiServices
  properties: {
    category: 'ApiKey'
    target: 'https://api.bing.microsoft.com/'
    authType: 'ApiKey'
    credentials: {
      key: bingGroundingKey
    }
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      type: 'bing_grounding'
      ResourceId: bingGroundingResourceId
    }
  }
  dependsOn: [
    project
  ]
}

resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = if (!empty(appInsightsId) && !empty(appInsightsConnectionString)) {
  name: '${resourceName}-appinsights'
  parent: aiServices
  properties: {
    category: 'AppInsights'
    target: appInsightsId
    authType: 'ApiKey'
    credentials: {
      key: appInsightsConnectionString
    }
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      type: 'app_insights'
      ResourceId: appInsightsId
    }
  }
  dependsOn: [
    project
    groundingWithBingConnection
  ]
}

resource roleAssignmentLoop 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinition in roleDefinitions: {
    name: guid(
      subscription().subscriptionId,
      '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/${roleDefinition}',
      '${resourceName}'
    )
    scope: aiServices
    properties: {
      principalId: project.identity.principalId
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinition)
      principalType: 'ServicePrincipal'
    }
  }
]

// Enabling diagnostics for the AI Service account (Microsoft.CognitiveServices)
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!(empty(logAnaltyicsWorkspaceId))) {
  name: 'diag'
  scope: aiServices
  properties: {
    workspaceId: logAnaltyicsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output endpoint string = aiServices.properties.endpoint
output identityObjectId string = aiServices.identity.principalId
output agentEndpoint string = project.properties.endpoints['AI Foundry API']
output modelName string = aiDeployment.properties.model.name
output modelDeploymentName string = aiDeployment.name
output projectResourceId string = project.id
output aiHubName string = aiServices.name
output aiProjectName string = project.name
output bingGroundingConnectionId string = groundingWithBingConnection.id
output appInsightsConnectionId string = appInsightsConnection.id
