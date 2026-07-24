variable "project_name" {
  description = "Short prefix for resource names."
  type        = string
}

variable "location" {
  description = "Azure region for monitoring resources."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Resource group the monitoring resources will live in."
  type        = string
}

variable "sql_server_id" {
  description = "Resource ID of the SQL server (from module.database.sql_server_id) — target for the auditing policy."
  type        = string
}

variable "sql_database_id" {
  description = "Resource ID of the SQL database (from module.database.database_id) — target for the DTU alert."
  type        = string
}

variable "app_service_id" {
  description = "Resource ID of the web app (from module.app.app_service_id) — target for diagnostics and the 5xx alert."
  type        = string
}

variable "alert_email" {
  description = "Email address that receives alert notifications."
  type        = string
}

variable "log_retention_days" {
  description = "Days to retain logs in the workspace. 30 is the free-tier-friendly floor."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default = {
    project    = "azure-webapp-iac"
    managed_by = "terraform"
  }
}
