data "azapi_resource" "vnet_rg" {
  type = "Microsoft.Resources/resourceGroups@2024-07-01"
  name = var.vnet_resource_group_name
}
data "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-10-01"
  name      = var.vnet_name
  parent_id = data.azapi_resource.vnet_rg.id
}

data "azapi_resource" "pe_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-10-01"
  name      = var.pe_subnet_name
  parent_id = data.azapi_resource.vnet.id
}
