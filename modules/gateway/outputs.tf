output "gateway_url" {
  description = "Public HTTPS entry point for the application."
  value       = "https://${azurerm_public_ip.agw.fqdn}"
}

output "gateway_name" {
  description = "Name of the Application Gateway (for az network application-gateway commands)."
  value       = azurerm_application_gateway.this.name
}

output "gateway_public_ip" {
  description = "Public IP address of the gateway."
  value       = azurerm_public_ip.agw.ip_address
}

output "key_vault_name" {
  description = "Name of the Key Vault holding the TLS certificate (suffix changes on each enable cycle)."
  value       = azurerm_key_vault.this.name
}
