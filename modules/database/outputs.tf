# The app module consumes these to build its connection string.
# Anything derived from the password is marked sensitive so Terraform
# redacts it from plan/apply output and CI logs.

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL server. Inside the VNet this resolves to the private endpoint IP."
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "database_name" {
  description = "Name of the application database."
  value       = azurerm_mssql_database.this.name
}

output "sql_admin_username" {
  description = "SQL administrator login."
  value       = var.sql_admin_username
}

output "sql_admin_password" {
  description = "Generated SQL administrator password. Redacted in console output; retrieve with: terraform output -raw sql_admin_password"
  value       = random_password.sql_admin.result
  sensitive   = true
}

output "connection_string" {
  description = "ODBC-style connection string for the app tier."
  value       = "Server=tcp:${azurerm_mssql_server.this.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.this.name};User ID=${var.sql_admin_username};Password=${random_password.sql_admin.result};Encrypt=yes;TrustServerCertificate=no;"
  sensitive   = true
}

output "sql_server_id" {
  description = "Resource ID of the SQL server (for auditing policy)."
  value       = azurerm_mssql_server.this.id
}

output "database_id" {
  description = "Resource ID of the database (for metric alerts)."
  value       = azurerm_mssql_database.this.id
}

