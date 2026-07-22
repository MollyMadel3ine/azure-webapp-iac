output "app_url" {
  description = "Public URL of the web app."
  value       = "https://${azurerm_linux_web_app.this.default_hostname}"
}

output "app_name" {
  description = "Name of the web app (needed for az webapp deploy)."
  value       = azurerm_linux_web_app.this.name
}

output "outbound_ip_addresses" {
  description = "Possible outbound IPs of the app — useful when debugging connectivity."
  value       = azurerm_linux_web_app.this.outbound_ip_addresses
}
