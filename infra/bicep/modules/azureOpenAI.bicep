targetScope = 'resourceGroup'

param location string = resourceGroup().location

param resourceName string = ''

param skuName string = 'S0'

param logAnaltyicsWorkspaceId string = ''

resource azureOpenAI 'Microsoft.CognitiveServices/accounts@2021-04-30' = {
  name: resourceName
  location: location
  sku: {
    name: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: resourceName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    restrictOutboundNetworkAccess: false
    }
  }

  resource aoaiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
    name: 'gpt-4o'
    parent: azureOpenAI
    
    sku: {
      capacity: 1
      name: 'Standard'
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-4o'
        version: '2024-08-06'
      }        
      versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    }
  }

  // Enabling diagnostics for the AI Service account (Microsoft.CognitiveServices)
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag'
  scope: azureOpenAI
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

  output endpoint string = azureOpenAI.properties.endpoint
  output identityObjectId string = azureOpenAI.identity.principalId

  output modelName string = aoaiDeployment.properties.model.name
  output modelDeploymentName string = aoaiDeployment.name
