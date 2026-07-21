variable "project_name" {
  description = "Short name used as a prefix for resource names (e.g., 'webapp-demo')."
  type        = string
}

variable "location" {
  description = "Azure region for all network resources."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Name of the resource group the network resources will live in."
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR block for the VNet."
  type        = string
  default     = "10.0.0.0/16"
}

variable "web_subnet_prefix" {
  description = "CIDR block for the web subnet. Must be inside the VNet address space."
  type        = string
  default     = "10.0.1.0/24"
}

variable "data_subnet_prefix" {
  description = "CIDR block for the data subnet. Must be inside the VNet address space."
  type        = string
  default     = "10.0.2.0/24"
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default = {
    project    = "azure-webapp-iac"
    managed_by = "terraform"
  }
}
