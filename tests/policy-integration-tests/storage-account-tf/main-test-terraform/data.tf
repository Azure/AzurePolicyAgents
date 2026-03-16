data "azapi_resource" "vnet_rg" {
  type = "Microsoft.Resources/resourceGroups@2025-04-01"
  name = local.vnetResourceGroupName
}
data "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-10-01"
  name      = local.vnetName
  parent_id = data.azapi_resource.vnet_rg.id
}

data "azapi_resource" "pe_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-10-01"
  name      = local.peSubnetName
  parent_id = data.azapi_resource.vnet.id
}
