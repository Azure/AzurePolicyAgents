resource "azapi_resource" "rg" {
  type     = "Microsoft.Resources/resourceGroups@2025-04-01"
  name     = var.resource_group_name
  location = var.location
}

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2025-06-01"
  name      = var.storage_account_name
  location  = var.location
  parent_id = azapi_resource.rg.id
  body = {
    sku = {
      name = "Standard_LRS"
    }
    tags = {
      application = "policy-integration-tests"
    }
    kind = "StorageV2"
    properties = {
      minimumTlsVersion           = "TLS1_1"  # Should violate policy STG-010
      allowSharedKeyAccess        = true      # Should violate policy STG-007
      allowCrossTenantReplication = true      # Should violate policy STG-006
      allowedCopyScope            = ""        # Should violate policy STG-012
      publicNetworkAccess         = "Enabled" # Should violate policy STG-009
      supportsHttpsTrafficOnly    = false     # Should violate policy STG-008
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Allow"
      }
    }
  }
}
