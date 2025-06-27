targetScope = 'resourceGroup'
param location string = resourceGroup().location
param resourceName string = 'logAnalytics'
param skuName string = 'PerGB2018'
param retentionInDays int = 30

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: resourceName
  location: location
  properties: {
    sku: {
      name: skuName
    }
    retentionInDays: retentionInDays
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
  }
}

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceName)
  location: location
  kind: 'Shared'
  properties: {
    displayName: 'MetroAgents'
    category: 'workbook'
    version: '1.0'
    sourceId: logAnalyticsWorkspace.id
    serializedData: loadTextContent('../workbooks/MetroAgents.txt')
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
