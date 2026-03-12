metadata itemDisplayName = 'Test Template for Storage Account'
metadata description = 'This template deploys the testing resource for Storage Account.'
metadata summary = 'Deploys test storage account resource that should be complaint with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var tags = globalConfig.tags
var location = localConfig.location
var namePrefix = globalConfig.namePrefix
var subName = localConfig.testSubscription
var vnetResourceGroup = globalConfig.subscriptions[subName].networkResourceGroup
var vnetName = globalConfig.subscriptions[subName].vNet
var peSubnetName = globalConfig.subscriptions[subName].peSubnet
var resourceSubnetName = globalConfig.subscriptions[subName].resourceSubnet

// define template specific variables
var serviceShort = 'stg2'
var storageAccountName = 'sa${namePrefix}${serviceShort}02'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
  resource resourceSubnet 'subnets' existing = { name: resourceSubnetName }
}

resource sa 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  kind: 'StorageV2'
  location: location
  name: storageAccountName
  sku: {
    name: 'Standard_LRS'
  }
  tags: tags
  properties: {
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowedCopyScope: 'AAD' //should comply with policy STG-012
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
      ipRules: []
    }
    minimumTlsVersion: 'TLS1_3'
    publicNetworkAccess: 'Disabled'
    encryption: { requireInfrastructureEncryption: true }
  }
}
output name string = sa.name
output resourceId string = sa.id
output location string = sa.location
