metadata itemDisplayName = 'Test Template for Key Vault'
metadata description = 'This template deploys the testing resource for Key Vault.'
metadata summary = 'Deploys test key vault resource.'

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
//var secretExpireDate = dateTimeToEpoch(dateTimeAdd(now, 'P2M'))
var keyExpireDate = dateTimeToEpoch(dateTimeAdd(now, 'P2M'))
// define template specific variables
var serviceShort = 'kv1'

//Key vault name must container a random string so it's unique for each test deployment.
//This is required because soft delete and purge protection is enabled. You cannot re-use the same KV name after deletion until the purge protection period has passed.
var keyVaultName = 'kv-${namePrefix}-${serviceShort}${keyVaultNameSuffix}01'
var peName = 'pe-${keyVaultName}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: az.resourceGroup(vnetResourceGroup)

  resource peSubnet 'subnets' existing = { name: peSubnetName }
  resource resourceSubnet 'subnets' existing = { name: resourceSubnetName }
}
module kv 'br/public:avm/res/key-vault/vault:0.6.2' = {
  name: '${uniqueString(deployment().name, location)}-test-kv-${serviceShort}'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    sku: 'premium'
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    privateEndpoints: [
      {
        name: peName
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
        rotationPolicy: {
          lifetimeActions: [
            {
              trigger: {
                timeBeforeExpiry: 'P30D'
              }
              action: {
                type: 'Notify'
              }
            }
          ]
        }
      }
    ]
    secrets: [
      {
        name: 'secret1'
        tags: tags
        attributes: {
          //exp: secretExpireDate //This should set 98728c90-32c7-4049-8429-847dc0f4fe37 (Key Vault secrets should have an expiration date) to nonCompliant
        }
        value: 'testValue1'
      }
    ]
  }
}

output name string = kv.outputs.name
output resourceId string = kv.outputs.resourceId
output location string = kv.outputs.location
output privateEndpointName string = peName
output resourceGroupId string = resourceGroup().id
