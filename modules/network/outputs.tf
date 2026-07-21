# Outputs are how other modules (app, database) consume this one.
# The app module needs the web subnet ID for VNet integration;
# the database module needs the data subnet ID for its private endpoint.

output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "web_subnet_id" {
  description = "ID of the web subnet (pass to the App Service VNet integration)."
  value       = azurerm_subnet.web.id
}

output "data_subnet_id" {
  description = "ID of the data subnet (pass to the SQL private endpoint)."
  value       = azurerm_subnet.data.id
}
