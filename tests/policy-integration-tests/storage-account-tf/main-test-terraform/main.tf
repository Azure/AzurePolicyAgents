resource "azapi_resource" "rg" {
  type     = "Microsoft.Resources/resourceGroups@2024-07-01"
  name     = var.resource_group_name
  location = local.location
}

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2024-01-01"
  name      = var.storage_account_name
  location  = local.location
  parent_id = azapi_resource.rg.id
  body = {
    sku = {
      name = "Standard_LRS"
    }
    kind = "StorageV2"
    properties = {
      minimumTlsVersion           = "TLS1_2"
      allowSharedKeyAccess        = false
      allowCrossTenantReplication = false
      allowedCopyScope            = "AAD"
      publicNetworkAccess         = "Disabled"
      supportsHttpsTrafficOnly    = true
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Deny"
      }
    }
  }
}

resource "azapi_resource" "storage_account_blob_pe" {
  type      = "Microsoft.Network/privateEndpoints@2024-07-01"
  name      = var.storage_account_blob_pe_name
  location  = local.location
  parent_id = azapi_resource.rg.id
  body = {
    properties = {
      customNetworkInterfaceName = var.storage_account_blob_pe_nic_name
      privateLinkServiceConnections = [
        {
          name = "blob-pls-connection"
          properties = {
            privateLinkServiceId = azapi_resource.storage_account.id
            groupIds             = ["blob"]
          }
        }
      ]
      subnet = {
        id = data.azapi_resource.pe_subnet.id
      }
    }
  }
}
