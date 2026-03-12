resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: 'vnet-ae-dev-network-01'
  scope: az.resourceGroup('rg-dev-network-01')

  resource peSubnet 'subnets' existing = { name: 'sn-private-endpoint' }
}

resource sa 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: 'sataotest03'
  location: 'australiaeast'
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: true
    allowedCopyScope: ''
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    minimumTlsVersion: 'TLS1_1'
  }
}

resource diagSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: sa
  properties: {
    workspaceId: '/subscriptions/a443bc8a-7305-4bb5-b895-80ee1e0698a6/resourceGroups/rg-monitor-01/providers/Microsoft.OperationalInsights/workspaces/law-ae-taolab-01'
    metrics: [
      {
        enabled: true
        category: 'Transaction'
      }
    ]
  }
}

resource storage_account_blob_pe 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: 'pe-sataotest03-blob'
  location: 'australiaeast'
  properties: {
    customNetworkInterfaceName: 'nic-pe-sataotest03-blob'
    privateLinkServiceConnections: [
      {
        name: 'blob-pls-connection'
        properties: {
          privateLinkServiceId: sa.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: vnet::peSubnet.id
    }
  }
}
output name string = sa.name
output resourceId string = sa.id
output location string = sa.location
