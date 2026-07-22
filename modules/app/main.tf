# ------------------------------------------------------------------
# App module
# Creates: App Service plan (B1 Linux) + Python web app with
# VNet integration into the web subnet.
#
# The asymmetry to understand: the app is PUBLICLY reachable on 443
# (that's the front door), while VNet integration gives it OUTBOUND
# access into the VNet — which is how it reaches the database's
# private endpoint. Public front, private back.
# ------------------------------------------------------------------

resource "azurerm_service_plan" "this" {
  name                = "${var.project_name}-asp"
  location            = var.location
  resource_group_name = var.resource_group_name

  os_type  = "Linux"
  sku_name = var.app_service_sku # B1 is the cheapest tier with VNet integration

  tags = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = "${var.project_name}-app" # part of the public URL — globally unique
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id

  https_only = true # pairs with the NSG story: no plaintext anywhere

  # Outbound path into the VNet → private endpoint → database.
  # Works because snet-web is delegated to Microsoft.Web/serverFarms
  # (pre-wired in the network module).
  virtual_network_subnet_id = var.web_subnet_id

  site_config {
    always_on = true # B1 supports it; keeps the health endpoint warm

    application_stack {
      python_version = "3.12"
    }

    # Route all outbound traffic through the VNet, not just RFC1918.
    # Belt-and-suspenders: DB traffic would route privately anyway,
    # but this makes the intent explicit.
    vnet_route_all_enabled = true
  }

  # Environment variables the application reads. The password arrives
  # from the database module's sensitive output — it transits Terraform
  # and state, never the repo. (Key Vault reference is the CI/CD-phase
  # upgrade.)
  app_settings = {
    DB_SERVER   = var.db_server_fqdn
    DB_NAME     = var.db_name
    DB_USER     = var.db_username
    DB_PASSWORD = var.db_password

    # Build the app from source on deploy (pip install requirements.txt)
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }

  tags = var.tags
}
