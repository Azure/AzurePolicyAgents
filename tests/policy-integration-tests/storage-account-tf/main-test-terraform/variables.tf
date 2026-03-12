variable "resource_group_name" {
  type    = string
  default = "rg-ae-d-policy-test-storage-002"
}

variable "storage_account_blob_pe_nic_name" {
  type    = string
  default = "nic_pe-sataoaztesttf03-blob-01"
}
variable "storage_account_blob_pe_name" {
  type    = string
  default = "pe-sataoaztesttf03-blob-01"
}
variable "storage_account_name" {
  type    = string
  default = "sataoaztesttf02"
}

variable "location" {
  type    = string
  default = "Australia East"
}

variable "vnet_name" {
  type    = string
  default = "vnet-ae-dev-network-01"
}

variable "vnet_resource_group_name" {
  type    = string
  default = "rg-dev-network-01"
}

variable "pe_subnet_name" {
  type    = string
  default = "sn-private-endpoint"
}
