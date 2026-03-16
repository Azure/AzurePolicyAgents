metadata itemDisplayName = 'Test Template for xxx'
metadata description = 'This template deploys the testing resource for xxx.'
metadata summary = 'Deploys test xxx resources that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'xxx3'
