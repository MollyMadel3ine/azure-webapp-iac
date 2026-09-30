# ==================================================================
# Gateway module - Phase 5: WAF-protected ingress
#
# Traffic path once this module is deployed:
#
#   Internet
#     -> Public IP (Standard, static)
#     -> Application Gateway WAF_v2          (snet-appgw)
#     -> App Service private endpoint        (snet-privateendpoints)
#     -> App Service -> VNet integration     (snet-web)
#     -> SQL private endpoint                (snet-data)
#
# The whole module is created and destroyed as one unit through the
# enable_app_gateway toggle in the root, because WAF_v2 bills by the
# hour whether or not it is serving traffic.
# ==================================================================

data "azurerm_client_config" "current" {}

locals {
  # App Gateway sub-blocks reference each other by NAME (plain strings),
  # not by Terraform resource address. Every name is defined once here so
  # a typo can't silently break the chain:
  #   listener -> routing rule -> backend pool + backend settings -> probe
  gateway_name           = "agw-${var.project_name}"
  gateway_ip_config_name = "gwipc-${var.project_name}"
  frontend_ip_name       = "feip-public"
  frontend_port_http     = "feport-80"
  frontend_port_https    = "feport-443"
  listener_http          = "listener-http"
  listener_https         = "listener-https"
  ssl_cert_name          = "cert-agw-tls"
  backend_pool_name      = "pool-appservice"
  backend_settings_name  = "settings-appservice-https"
  probe_name             = "probe-health"
  redirect_name          = "redirect-http-to-https"
  rule_redirect          = "rule-http-redirect"
  rule_https             = "rule-https-to-app"

  # Public DNS label -> <label>.<region>.cloudapp.azure.com
  # Must be unique within the region, hence project_name in it.
  dns_label = "${var.project_name}-agw"
}

# ---------------- Gateway subnet ----------------
# App Gateway v2 requires a DEDICATED subnet - no other resource types
# may live in it. /24 is Microsoft's recommendation: it leaves room for
# autoscale instances and a private frontend IP later.
#
# Why not reuse snet-web: that subnet is delegated to
# Microsoft.Web/serverFarms for the App Service's VNet integration, and a
# delegated subnet can't host an App Gateway.

resource "azurerm_subnet" "agw" {
  name                 = "snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.gateway_subnet_prefix]
}

resource "azurerm_network_security_group" "agw" {
  name                = "nsg-appgw-${var.project_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # REQUIRED for v2: Azure's control plane manages the gateway
  # instances on these ports. If this rule is missing, the deployment
  # fails or the gateway ends up in a Failed state.
  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  # REQUIRED: health probes from the platform load balancer that sits
  # in front of the gateway instances.
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # The public listeners. This is the ONE place in the environment that
  # accepts internet traffic on purpose. Port 80 exists only so the
  # gateway can answer with a 301 redirect to HTTPS - nothing on port 80
  # is ever forwarded to the backend.
  # Justification for the tfsec ignore below: public ingress is this
  # subnet's purpose, and WAF_v2 inspects every request before it
  # reaches the backend.
  #tfsec:ignore:azure-network-no-public-ingress
  security_rule {
    name                       = "AllowInternetHttpHttps"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Explicit deny, same convention as the web and data NSGs. Microsoft
  # documents this as supported for v2 as long as the three rules above
  # sit at higher priority.
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "agw" {
  subnet_id                 = azurerm_subnet.agw.id
  network_security_group_id = azurerm_network_security_group.agw.id
}

# ---------------- Private endpoint subnet ----------------
# Holds the App Service's inbound private endpoint. It's kept separate
# from snet-data so the app tier and data tier stay in different
# subnets with different NSG rules.

resource "azurerm_subnet" "pe" {
  name                 = "snet-privateendpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.pe_subnet_prefix]

  # By default, NSG rules are NOT enforced on private endpoints. This
  # setting turns enforcement on - without it, the NSG below would be
  # decorative.
  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
}

resource "azurerm_network_security_group" "pe" {
  name                = "nsg-privateendpoints-${var.project_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Least privilege, same pattern as the data NSG: the source is the
  # gateway subnet's CIDR, not the VirtualNetwork tag. Only the gateway
  # can reach the app's private endpoint.
  security_rule {
    name                       = "AllowHttpsFromGateway"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.gateway_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe.id
}

# ---------------- App Service private endpoint + DNS ----------------
# Same pattern as the database module:
#   1. A private endpoint gives the app a private IP in snet-privateendpoints.
#   2. The privatelink.azurewebsites.net zone (exact name required),
#      linked to the VNet, makes <app>.azurewebsites.net resolve to that
#      private IP for anything inside the VNet - including the gateway.
# Without step 2, the gateway resolves the public IP, hits the access
# restriction, gets a 403, and marks the backend Unhealthy.

resource "azurerm_private_dns_zone" "webapp" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "webapp" {
  name                  = "link-webapp-${var.project_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.webapp.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "app" {
  name                = "pe-app-${var.project_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.pe.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-app-${var.project_name}"
    private_connection_resource_id = var.app_service_id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  # Creates the A records (<app> and <app>.scm) in the zone automatically.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.webapp.id]
  }

  depends_on = [azurerm_subnet_network_security_group_association.pe]
}

# ---------------- Gateway identity + Key Vault TLS certificate ----------------
# The gateway reads its TLS certificate from Key Vault using a
# user-assigned managed identity. There are no certificate files on disk
# and no passwords in pipeline variables.
#
# Access POLICIES instead of RBAC: the pipeline's service principal is
# Contributor on one resource group, and Contributor cannot create role
# assignments by design. Access policies are written through the vault's
# ARM resource, which Contributor can manage. See the design-decision
# notes in PHASE5_WIRING.md for the trade-off.

resource "azurerm_user_assigned_identity" "agw" {
  name                = "id-agw-${var.project_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# A random suffix gives every enable/disable cycle a fresh vault name.
# Destroyed vaults are soft-deleted (retained 7 days, free) and are NOT
# purged, because purging needs subscription-scope permissions the
# pipeline identity deliberately doesn't have.
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Justifications for the tfsec ignores below:
# - specify-network-acl: Microsoft-hosted pipeline agents need data-plane
#   access to create the certificate. Restricting the vault firewall
#   requires a self-hosted agent inside the VNet. This is a documented
#   deferral, the same approach as the Phase 1 SQL auditing finding.
# - no-purge: this vault is intentionally short-lived (destroyed with
#   the gateway). Purge protection would block that lifecycle.
#tfsec:ignore:azure-keyvault-specify-network-acl
#tfsec:ignore:azure-keyvault-no-purge
resource "azurerm_key_vault" "this" {
  name                       = "kv-agw-${random_string.kv_suffix.result}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags

  # Whoever runs terraform apply (the pipeline SP) needs to create,
  # read, and clean up the certificate.
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Create", "Delete", "Get", "GetIssuers", "Import",
      "List", "ListIssuers", "Purge", "Recover", "Update",
    ]
    secret_permissions = ["Get", "List"]
  }

  # The gateway only needs to READ the certificate. App Gateway fetches
  # it through the secrets API, so this is one permission: secret Get.
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.agw.principal_id

    secret_permissions = ["Get"]
  }
}

resource "azurerm_public_ip" "agw" {
  name                = "pip-agw-${var.project_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard" # required for v2
  allocation_method   = "Static"   # required for v2
  domain_name_label   = local.dns_label
  tags                = var.tags
}

# Self-signed certificate generated INSIDE Key Vault, so the private key
# never leaves the vault. Its CN is the public IP's Azure FQDN, which
# gives the gateway a stable hostname without buying a domain. Browsers
# and curl will warn (use curl -k). Swapping in a real certificate later
# changes only this resource.
resource "azurerm_key_vault_certificate" "agw" {
  name         = "agw-tls"
  key_vault_id = azurerm_key_vault.this.id
  tags         = var.tags

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=${azurerm_public_ip.agw.fqdn}"
      validity_in_months = 12
      key_usage          = ["digitalSignature", "keyEncipherment"]
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # TLS server authentication

      subject_alternative_names {
        dns_names = [azurerm_public_ip.agw.fqdn]
      }
    }
  }
}

# ---------------- WAF policy ----------------
# This is a standalone policy resource rather than the legacy inline
# waf_configuration block, so it can later be shared across gateways or
# attached per listener.
#
# Mode starts as "Detection": requests that match rules are logged but
# not blocked. Review the logs for false positives, then flip to
# "Prevention" through a PR.

resource "azurerm_web_application_firewall_policy" "this" {
  name                = "wafpol-${var.project_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  policy_settings {
    enabled            = true
    mode               = var.waf_mode
    request_body_check = true
  }

  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
    }
  }
}

# ---------------- Application Gateway ----------------

resource "azurerm_application_gateway" "this" {
  name                              = local.gateway_name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  firewall_policy_id                = azurerm_web_application_firewall_policy.this.id
  force_firewall_policy_association = true
  tags                              = var.tags

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
    # No capacity here - autoscale_configuration below replaces it.
  }

  # min 0 = no reserved instances. The fixed hourly charge still
  # applies; capacity-unit charges scale with traffic.
  autoscale_configuration {
    min_capacity = 0
    max_capacity = var.max_capacity
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agw.id]
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_config_name
    subnet_id = azurerm_subnet.agw.id
  }

  # ---- Frontend: where traffic arrives ----

  frontend_ip_configuration {
    name                 = local.frontend_ip_name
    public_ip_address_id = azurerm_public_ip.agw.id
  }

  frontend_port {
    name = local.frontend_port_http
    port = 80
  }

  frontend_port {
    name = local.frontend_port_https
    port = 443
  }

  # ---- TLS ----

  # Versionless secret ID: when Key Vault auto-renews the certificate,
  # the gateway picks up the new version on its own (it polls roughly
  # every 4 hours). No Terraform change is needed.
  ssl_certificate {
    name                = local.ssl_cert_name
    key_vault_secret_id = azurerm_key_vault_certificate.agw.versionless_secret_id
  }

  # TLS 1.2+ with modern ciphers. The old default policy allowed TLS
  # 1.0/1.1 and has been retired.
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  # ---- Listeners ----

  http_listener {
    name                           = local.listener_http
    frontend_ip_configuration_name = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_http
    protocol                       = "Http"
  }

  http_listener {
    name                           = local.listener_https
    frontend_ip_configuration_name = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_https
    protocol                       = "Https"
    ssl_certificate_name           = local.ssl_cert_name
  }

  # ---- Backend: where traffic goes ----

  # The FQDN, not an IP. Through the private DNS zone it resolves to the
  # private endpoint's IP.
  backend_address_pool {
    name  = local.backend_pool_name
    fqdns = [var.app_default_hostname]
  }

  # HTTPS end to end: TLS terminates at the gateway, and the gateway
  # re-encrypts to the backend.
  #
  # pick_host_name_from_backend_address = true is REQUIRED for App
  # Service. App Service routes requests by Host header, so the gateway
  # must send "<app>.azurewebsites.net" rather than the gateway's own
  # hostname. Without it you get 404s. The backend's certificate is the
  # Microsoft-issued *.azurewebsites.net wildcard, which v2 already
  # trusts, so no trusted root certificate needs to be uploaded.
  backend_http_settings {
    name                                = local.backend_settings_name
    port                                = 443
    protocol                            = "Https"
    cookie_based_affinity               = "Disabled"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = local.probe_name
  }

  # Probes /health, the endpoint that makes a real SQL round-trip.
  # A healthy probe therefore proves the whole chain works: gateway ->
  # private endpoint -> app -> VNet integration -> SQL private endpoint.
  #
  # The body match is what makes this probe honest: the request must
  # return 200-399 AND contain "connected" (quotes included, so a value
  # like "disconnected" can't match). If the app is up but the database
  # is unreachable, the backend is still marked Unhealthy.
  probe {
    name                                      = local.probe_name
    protocol                                  = "Https"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
      body        = "\"connected\""
    }
  }

  # ---- Routing ----

  redirect_configuration {
    name                 = local.redirect_name
    redirect_type        = "Permanent"
    target_listener_name = local.listener_https
    include_path         = true
    include_query_string = true
  }

  # Port 80 -> 301 redirect to HTTPS. Never reaches the backend.
  request_routing_rule {
    name                        = local.rule_redirect
    priority                    = 100
    rule_type                   = "Basic"
    http_listener_name          = local.listener_http
    redirect_configuration_name = local.redirect_name
  }

  # Port 443 -> the App Service.
  request_routing_rule {
    name                       = local.rule_https
    priority                   = 200
    rule_type                  = "Basic"
    http_listener_name         = local.listener_https
    backend_address_pool_name  = local.backend_pool_name
    backend_http_settings_name = local.backend_settings_name
  }

  # Explicit ordering, because none of these are referenced above:
  # - The NSG must be attached before the gateway deploys into the subnet.
  # - The private endpoint and DNS link must exist before the gateway
  #   first resolves the backend FQDN. Otherwise it can resolve and cache
  #   the PUBLIC IP, and the backend shows Unhealthy (403) until the
  #   cached lookup expires.
  depends_on = [
    azurerm_subnet_network_security_group_association.agw,
    azurerm_private_endpoint.app,
    azurerm_private_dns_zone_virtual_network_link.webapp,
  ]
}

# ---------------- Diagnostics ----------------
# "Dedicated" sends logs to resource-specific tables (AGWAccessLogs,
# AGWFirewallLogs) instead of the shared AzureDiagnostics table. That
# gives typed columns and simpler KQL.

resource "azurerm_monitor_diagnostic_setting" "agw" {
  name                           = "${var.project_name}-agw-diag"
  target_resource_id             = azurerm_application_gateway.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }
}

# ---------------- Alert ----------------
# Fires when the gateway can't reach a healthy backend. Because the
# probe hits /health with a body match, this also covers "app up,
# database down". Routes to the existing action group from the
# monitoring module.

resource "azurerm_monitor_metric_alert" "unhealthy_backend" {
  name                = "${var.project_name}-agw-unhealthy-backend"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_gateway.this.id]
  description         = "App Gateway reports unhealthy backend hosts: /health is failing through the gateway."
  severity            = 1 # error
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags
}
