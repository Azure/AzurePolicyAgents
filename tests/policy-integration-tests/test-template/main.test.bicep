metadata itemDisplayName = 'Test Template for xxx'
metadata description = 'This template deploys the testing resource for xxx.'
metadata summary = 'Deploys test xxx resources.'

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
//Define required variables from the configuration files - change these based on your requirements
var tags = globalConfig.tags
var location = localConfig.location
var namePrefix = globalConfig.namePrefix
var subName = localConfig.testSubscription
var vnetResourceGroup = globalConfig.subscriptions[subName].networkResourceGroup
var vnetName = globalConfig.subscriptions[subName].vNet
var peSubnetName = globalConfig.subscriptions[subName].peSubnet
var resourceSubnetName = globalConfig.subscriptions[subName].resourceSubnet

var serviceShort = 'xxx1' //use this to form the name of the resources deployed by this template. This is helpful to identify the resource in the portal and also useful if you want to have a policy that targets specific resources by name. For example, if you have a policy that audits whether storage accounts have secure transfer enabled, you can set serviceShort to 'st' and then in the policy definition, you can target resources with name starting with 'st' to only audit the storage accounts deployed by this test template.

// ============ //
// resources    //
// ============ //

// ============ //
// outputs      //
// ============ //
//Specify the outputs that are required for the test
