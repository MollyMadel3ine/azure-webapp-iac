variable "project_name" {
  description = "Short name used as a prefix for resource names. SQL server names must be globally unique, so this may need adjusting."
  type        = string
}

variable "location" {
  description = "Azure region for the database resources."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Resource group the database resources will live in."
  type        = string
}

variable "vnet_id" {
  description = "ID of the VNet to link the private DNS zone to (from module.network.vnet_id)."
  type        = string
}

variable "data_subnet_id" {
  description = "ID of the data subnet where the private endpoint lives (from module.network.data_subnet_id)."
  type        = string
}

variable "sql_admin_username" {
  description = "Administrator login for the SQL server. Not a secret by itself, but avoid the obvious 'sa'/'admin' (Azure rejects several reserved names anyway)."
  type        = string
  default     = "sqladminuser"
}

variable "database_name" {
  description = "Name of the database itself."
  type        = string
  default     = "appdb"
}

variable "database_sku" {
  description = "SKU for the database. 'Basic' is ~$5/month. 'GP_S_Gen5_1' (serverless) auto-pauses when idle if you prefer scale-to-zero."
  type        = string
  default     = "Basic"
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default = {
    project    = "azure-webapp-iac"
    managed_by = "terraform"
  }
}
