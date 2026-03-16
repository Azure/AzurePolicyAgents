targetScope = 'subscription'
metadata itemDisplayName = 'Test Template for Tags'
metadata description = 'This template deploys the testing resource for Tags.'
metadata summary = 'Deploys test resource for testing tagging policies.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location

var namePrefix = globalConfig.namePrefix
// define template specific variables
var serviceShort = 'tag1'
var rgName = 'rg-${namePrefix}-${serviceShort}-01'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
}

output name string = resourceGroup.name
output resourceId string = resourceGroup.id
output location string = resourceGroup.location
