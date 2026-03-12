terraform {
  required_version = ">=1.11.3"
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.5"
    }
  }
}
# Configure the Microsoft Azure Provider
provider "azapi" {
  subscription_id = "46aa6fb9-01f8-4acc-b67c-ee355f6b6fa0"
}
