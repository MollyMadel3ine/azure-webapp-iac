# ------------------------------------------------------------------
# Database module
# Creates: Azure SQL Server + Database, reachable ONLY through a
# private endpoint in the data subnet. Public network access is
# disabled at the server level — the database has no internet path,
# by configuration and not just by NSG rule.
#
# Also creates the Private DNS zone that makes the private endpoint
# actually usable: without it, the server's hostname still resolves
# to a public IP and connections fail.
# ------------------------------------------------------------------

# ---------------- Credentials ----------------
# Generate the admin password rather than passing it in, so no secret
# ever appears in a tfvars file or shell history. It still lands in
# remote state — which is exactly why state is access-controlled and
# never committed. (Phase 2 moves secrets to Key Vault.)

resource "random_password" "sql_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------- SQL Server ----------------

resource "azurerm_mssql_server" "this" {
  name                         = "${var.project_name}-sql"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"

  # The headline setting: no public endpoint exists at all.
  public_network_access_enabled = false

  tags = var.tags
}

# ---------------- Database ----------------

resource "azurerm_mssql_database" "this" {
  name      = var.database_name
  server_id = azurerm_mssql_server.this.id

  # Basic tier: ~$5/month, plenty for a portfolio health endpoint.
  sku_name     = var.database_sku
  max_size_gb  = 2
  license_type = "LicenseIncluded"

  tags = var.tags
}

# ---------------- Private DNS zone ----------------
# Azure SQL clients always connect to <server>.database.windows.net.
# This zone overrides that name INSIDE the VNet so it resolves to the
# private endpoint's IP instead of the public one.

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net" # exact name required
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "${var.project_name}-sql-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# ---------------- Private endpoint ----------------
# A NIC in the data subnet that IS the database's only front door.

resource "azurerm_private_endpoint" "sql" {
  name                = "${var.project_name}-sql-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.data_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.project_name}-sql-psc"
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  # Auto-registers the server's A record in the private DNS zone.
  private_dns_zone_group {
    name                 = "sql-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}
