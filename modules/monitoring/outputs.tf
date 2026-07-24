output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Name of the workspace (for az monitor / KQL queries)."
  value       = azurerm_log_analytics_workspace.this.name
}
