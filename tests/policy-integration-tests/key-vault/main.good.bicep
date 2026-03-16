metadata itemDisplayName = 'Test Template for Key Vault'
metadata description = 'This template deploys the testing resource for Key Vault.'
metadata summary = 'Deploys test key vault resource that should comply with all policy assignments.'

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

var keyVaultNameSuffix = substring((uniqueString(now, location)), 0, 5)
// define template specific variables
var serviceShort = 'kv3'

//Key vault name must contain a random string so it's unique for each test deployment.
//This is required because soft delete and purge protection is enabled. You cannot re-use the same KV name after deletion until the purge protection period has passed.
var keyVaultName = 'kv-${namePrefix}-${serviceShort}${keyVaultNameSuffix}01'

resource kv 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'premium'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enablePurgeProtection: true //should comply with KV-002
    enableRbacAuthorization: true //Should comply with KV-003
    publicNetworkAccess: 'Disabled' //Should comply with KV-004
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

output name string = kv.name
output resourceId string = kv.id
output location string = kv.location
