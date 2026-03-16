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
  subscription_id = "555d629d-907b-4877-8075-bb45d49e7a04"
}
