output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Name of the workspace (for az monitor / KQL queries)."
  value       = azurerm_log_analytics_workspace.this.name
}
output "action_group_id" {
  description = "ID of the alerts action group(consumed by the gateway module)."
  value       = azurerm_monitor_action_group.this.id
}
