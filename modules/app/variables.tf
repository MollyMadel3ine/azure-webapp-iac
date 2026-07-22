variable "project_name" {
  description = "Short prefix for resource names. The web app name becomes <project_name>-app.azurewebsites.net, so it must be globally unique."
  type        = string
}

variable "location" {
  description = "Azure region for the app resources."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Resource group the app resources will live in."
  type        = string
}

variable "web_subnet_id" {
  description = "ID of the web subnet for VNet integration (from module.network.web_subnet_id)."
  type        = string
}

variable "app_service_sku" {
  description = "App Service plan SKU. B1 (~$13/mo) is the cheapest supporting VNet integration; F1 (free) does NOT support it."
  type        = string
  default     = "B1"
}

variable "db_server_fqdn" {
  description = "SQL server FQDN (from module.database.sql_server_fqdn). Resolves to the private endpoint IP inside the VNet."
  type        = string
}

variable "db_name" {
  description = "Database name (from module.database.database_name)."
  type        = string
}

variable "db_username" {
  description = "SQL admin username (from module.database.sql_admin_username)."
  type        = string
}

variable "db_password" {
  description = "SQL admin password (from module.database.sql_admin_password)."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default = {
    project    = "azure-webapp-iac"
    managed_by = "terraform"
  }
}
