metadata itemDisplayName = 'Test Template for Key Vault'
metadata description = 'This template deploys the testing resource for Key Vault.'
metadata summary = 'Deploys test key vault resource that should violate some policy assignments.'

// ========== //
// Parameters //
// ========== //

@description('Optional. Get current time stamp. This is used to generate unique name for key vault. DO NOT provide a value.')
param now string = utcNow()

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
var keyVaultNameSuffix = substring((uniqueString(now, location)), 0, 5)
// define template specific variables
var serviceShort = 'kv2'

//Key vault name must container a random string so it's unique for each test deployment.
//This is required because soft delete and purge protection is enabled. You cannot re-use the same KV name after deletion until the purge protection period has passed.
var keyVaultName = 'kv-${namePrefix}-${serviceShort}01'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
  resource resourceSubnet 'subnets' existing = { name: resourceSubnetName }
}

resource kv 'Microsoft.KeyVault/vaults@2024-12-01-preview' = {
  location: location
  name: keyVaultName
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'premium'
    }
    publicNetworkAccess: 'Enabled'
    enableRbacAuthorization: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

output name string = kv.name
output resourceId string = kv.id
output location string = kv.location
