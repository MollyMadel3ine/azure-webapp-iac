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