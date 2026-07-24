# ------------------------------------------------------------------
# Monitoring module
# Creates: Log Analytics workspace (the central log sink), SQL audit
# logging into it (closing the deferred tfsec finding properly),
# diagnostic settings for the app, an action group, and two metric
# alerts that represent real operational signals.
# ------------------------------------------------------------------

# ---------------- Log Analytics workspace ----------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.project_name}-law"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku               = "PerGB2018" # pay-as-you-go; demo volumes cost pennies
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ---------------- SQL audit logging ----------------
# Two resources work together to land audit events in Log Analytics:
#  1. The extended auditing policy turns auditing ON at the server,
#     in "log monitoring" mode (no storage account involved).
#  2. A diagnostic setting on the server's master database routes the
#     SQLSecurityAuditEvents category to the workspace.
# This is the proper closure of the tfsec finding that was deferred
# with an annotation in the database module.

resource "azurerm_mssql_server_extended_auditing_policy" "this" {
  server_id              = var.sql_server_id
  log_monitoring_enabled = true
}

resource "azurerm_monitor_diagnostic_setting" "sql_audit" {
  name                       = "${var.project_name}-sql-audit"
  target_resource_id         = "${var.sql_server_id}/databases/master"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  depends_on = [azurerm_mssql_server_extended_auditing_policy.this]
}

# ---------------- App Service diagnostics ----------------

resource "azurerm_monitor_diagnostic_setting" "app" {
  name                       = "${var.project_name}-app-diag"
  target_resource_id         = var.app_service_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

# ---------------- Action group ----------------
# Where alerts go. Email for a demo; a real environment would add
# PagerDuty / Teams / webhook receivers here.

resource "azurerm_monitor_action_group" "this" {
  name                = "${var.project_name}-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "webappiac" # max 12 chars, shows in SMS/email subjects

  email_receiver {
    name                    = "primary-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = var.tags
}

# ---------------- Metric alerts ----------------

# Alert 1: the app is throwing server errors.
resource "azurerm_monitor_metric_alert" "http_5xx" {
  name                = "${var.project_name}-http-5xx"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_service_id]
  description         = "App Service is returning HTTP 5xx responses."
  severity            = 2 # warning
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }

  tags = var.tags
}

# Alert 2: the database is running hot.
resource "azurerm_monitor_metric_alert" "sql_dtu" {
  name                = "${var.project_name}-sql-dtu"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_database_id]
  description         = "SQL database DTU consumption is sustained above 80%."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "dtu_consumption_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }

  tags = var.tags
}
