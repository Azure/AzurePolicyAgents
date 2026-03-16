metadata itemDisplayName = 'Test Template for Tagging Policy Assignment (Resource)'
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
  dataclass: 'official-internal' //this should violate the policy TAG-014: Resource Should have required tag value (dataclass). 'official-internal' is not one of the allowed values
  environment: 'hell' //this should violate the policy TAG-017: Resource Should have required tag value (environment). 'hell' is not one of the allowed values
}
// define template specific variables
var serviceShort = 'tag'
var uamiName = 'uami-${namePrefix}-${serviceShort}-01'

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
  tags: tags
}

@description('The ID of the resource created.')
output resourceId string = uami.id

@description('The name of the resource.')
output name string = uami.name

@description('The location of the resource.')
output location string = uami.location
