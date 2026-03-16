targetScope = 'subscription'
metadata itemDisplayName = 'Test Template for Tagging Policy Assignment (Resource Group)'
metadata description = 'This template deploys the testing resource for Tagging Policy Assignment.'
metadata summary = 'Deploys test a resource that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location

var namePrefix = globalConfig.namePrefix
var tags = {
  dataclass: 'official-internal' //this should violate the policy TAG-013: Resource Group Should have required tag value (dataclass). 'official-internal' is not one of the allowed values
  environment: 'hell' //this should violate the policy TAG-016: Resource Group Should have required tag value (environment). 'hell' is not one of the allowed values
}
// define template specific variables
var serviceShort = 'tag'
var rgName = 'rg-${namePrefix}-${serviceShort}-01'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

@description('The ID of the resource group created.')
output resourceId string = resourceGroup.id

@description('The name of the resource group.')
output name string = resourceGroup.name

@description('The location of the resource group.')
output location string = resourceGroup.location
