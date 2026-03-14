terraform {
  required_version = ">=1.14.6"
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.5"
    }
  }
}
# Configure the Microsoft Azure Provider
provider "azapi" {
  subscription_id = "dc2d72b7-a48d-45e8-91cc-81193ecc659b"
}
