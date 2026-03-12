metadata itemDisplayName = 'Test Template for Storage Account'
metadata description = 'This template deploys the testing resource for Storage Account.'
metadata summary = 'Deploys test storage account resource that should violate some policy assignments.'

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
var serviceShort = 'stg3'
var storageAccountName = 'sa${namePrefix}${serviceShort}03'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
  resource resourceSubnet 'subnets' existing = { name: resourceSubnetName }
}
module sa 'br/public:avm/res/storage/storage-account:0.9.1' = {
  name: '${uniqueString(deployment().name, location)}-test-${serviceShort}'
  params: {
    name: storageAccountName
    location: location
    tags: tags
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: true
    allowedCopyScope: '' //should violate policy STG-012
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow' //should be blocked by policy
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: [
        {
          id: vnet::resourceSubnet.id
          action: 'Allow'
        }
      ]
    }
    enableHierarchicalNamespace: true
    supportsHttpsTrafficOnly: false
    minimumTlsVersion: 'TLS1_1'
    privateEndpoints: [
      {
        name: 'pe-${storageAccountName}-blob'
        service: 'blob'
        subnetResourceId: vnet::peSubnet.id
        tags: tags
      }
      {
        name: 'pe-${storageAccountName}-dfs'
        service: 'dfs'
        subnetResourceId: vnet::peSubnet.id
        tags: tags
      }
    ]
  }
}

output name string = sa.outputs.name
output resourceId string = sa.outputs.resourceId
output location string = sa.outputs.location
