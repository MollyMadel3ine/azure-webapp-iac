variable "project_name" {
  description = "Prefix for resource names. Also forms the public DNS label (<project_name>-agw.<region>.cloudapp.azure.com), which must be unique within the region."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "vnet_name" {
  description = "Name of the existing VNet (from module.network.vnet_name). The gateway and private-endpoint subnets are added to it."
  type        = string
}

variable "vnet_id" {
  description = "ID of the existing VNet (from module.network.vnet_id). The privatelink.azurewebsites.net zone is linked to it."
  type        = string
}

variable "gateway_subnet_prefix" {
  description = "CIDR for the dedicated App Gateway subnet. Must be inside the VNet and must not overlap snet-web (10.0.1.0/24) or snet-data (10.0.2.0/24)."
  type        = string
  default     = "10.0.3.0/24"
}

variable "pe_subnet_prefix" {
  description = "CIDR for the private endpoint subnet that holds the App Service's inbound private endpoint."
  type        = string
  default     = "10.0.4.0/24"
}

variable "app_service_id" {
  description = "Resource ID of the web app (from module.app.app_service_id). Target of the private endpoint."
  type        = string
}

variable "app_default_hostname" {
  description = "Default hostname of the web app, e.g. <app>.azurewebsites.net (from module.app.app_default_hostname). Used as the backend pool FQDN."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID (from module.monitoring.workspace_id). Receives access and WAF logs."
  type        = string
}

variable "action_group_id" {
  description = "Action group ID (from module.monitoring.action_group_id). Receives the unhealthy-backend alert."
  type        = string
}

variable "waf_mode" {
  description = "WAF mode. Detection logs matches without blocking; Prevention blocks them. Start in Detection, then flip via PR."
  type        = string
  default     = "Detection"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "waf_mode must be \"Detection\" or \"Prevention\" (case-sensitive)."
  }
}

variable "max_capacity" {
  description = "Autoscale ceiling in instances. 2 is plenty for a demo."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags applied to all taggable resources in this module."
  type        = map(string)
  default = {
    project    = "azure-webapp-iac"
    managed_by = "terraform"
  }
}
