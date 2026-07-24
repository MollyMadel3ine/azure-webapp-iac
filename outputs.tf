# outputs.tf (repo root)

output "sql_server_fqdn" {
  description = "FQDN of the SQL server."
  value       = module.database.sql_server_fqdn
}

output "sql_admin_password" {
  description = "Generated SQL admin password."
  value       = module.database.sql_admin_password
  sensitive   = true
}

output "connection_string" {
  description = "Connection string for the app tier."
  value       = module.database.connection_string
  sensitive   = true
}

output "app_url" {
  description = "Public URL of the web app."
  value       = module.app.app_url
}

output "app_name" {
  description = "Name of the web app (for az webapp deploy commands)."
  value       = module.app.app_name
}

output "log_analytics_workspace" {
  description = "Workspace name for KQL queries."
  value       = module.monitoring.workspace_name
}
