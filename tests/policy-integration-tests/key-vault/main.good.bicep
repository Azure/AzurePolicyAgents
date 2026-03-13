metadata itemDisplayName = 'Test Template for Key Vault'
metadata description = 'This template deploys the testing resource for Key Vault.'
metadata summary = 'Deploys test key vault resource that should compplaint with all policy assignments.'

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
var secretExpireDate = dateTimeToEpoch(dateTimeAdd(now, 'P2M'))
var secretNotBeforeDate = dateTimeToEpoch(now)
var keyExpireDate = dateTimeToEpoch(dateTimeAdd(now, 'P6M'))
var keyNotBeforeDate = dateTimeToEpoch(now)
// define template specific variables
var serviceShort = 'kv3'

//Key vault name must container a random string so it's unique for each test deployment.
//This is required because soft delete and purge protection is enabled. You cannot re-use the same KV name after deletion until the purge protection period has passed.
var keyVaultName = 'kv-${namePrefix}-${serviceShort}${keyVaultNameSuffix}01'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
  resource resourceSubnet 'subnets' existing = { name: resourceSubnetName }
}

module kv 'br/public:avm/res/key-vault/vault:0.13.3' = {
  name: '${uniqueString(deployment().name, location)}-test-kv-${serviceShort}'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    sku: 'premium'
    publicNetworkAccess: 'Disabled'
    enableSoftDelete: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    privateEndpoints: [
      {
        name: 'pe-${keyVaultName}'
        subnetResourceId: vnet::peSubnet.id
        service: 'vault'
        tags: tags
      }
    ]
    keys: [
      {
        name: 'key1'
        tags: tags
        kty: 'RSA-HSM'
        attributes: {
          exp: keyExpireDate
        }
      }
      {
        name: 'key2'
        tags: tags
        kty: 'RSA-HSM'
        attributes: {
          exp: keyExpireDate
          nbf: keyNotBeforeDate
        }
      }
    ]
    secrets: [
      {
        name: 'secret1'
        tags: tags
        attributes: {
          exp: secretExpireDate
        }
        value: 'testValue1'
      }
      {
        name: 'secret2'
        tags: tags
        attributes: {
          exp: secretExpireDate
          nbf: secretNotBeforeDate
        }
        value: 'testValue1'
      }
    ]
  }
}

output name string = kv.outputs.name
output resourceId string = kv.outputs.resourceId
output location string = kv.outputs.location
