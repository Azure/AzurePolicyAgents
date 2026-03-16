locals {
  globalconfig          = jsondecode(replace(file("${path.module}/../../.shared/policy_integration_test_config.jsonc"), "/\\/\\/[^\\n]*/", ""))
  localconfig           = jsondecode(file("${path.module}/../config.json"))
  subName               = local.localconfig.testSubscription
  vnetName              = local.globalconfig.subscriptions[local.subName].vNet
  vnetResourceGroupName = local.globalconfig.subscriptions[local.subName].networkResourceGroup
  peSubnetName          = local.globalconfig.subscriptions[local.subName].peSubnet
  location              = local.localconfig.location
}
