metadata itemDisplayName = 'Test Template for xxxx'
metadata description = 'This template deploys the testing resource for xxxx.'
metadata summary = 'Deploys test xxxx resources that should comply with all policy assignments.'

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
