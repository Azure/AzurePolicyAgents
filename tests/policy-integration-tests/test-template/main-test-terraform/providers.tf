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
  subscription_id = "" // specify the subscription where the resources will be deployed.
}
