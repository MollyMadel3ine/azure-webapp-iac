# Monitoring phase — wiring instructions

Instructions only — this is a .md on purpose, so nothing here can end up
executed by Terraform if it lands in the wrong folder. Work through it
top to bottom, then delete it or keep it as docs/.

## 1. New outputs needed in EXISTING modules

The monitoring module consumes resource IDs the other modules don't
export yet. Add these:

**modules/database/outputs.tf** — append:

```hcl
output "sql_server_id" {
  description = "Resource ID of the SQL server (for auditing policy)."
  value       = azurerm_mssql_server.this.id
}

output "database_id" {
  description = "Resource ID of the database (for metric alerts)."
  value       = azurerm_mssql_database.this.id
}
```

**modules/app/outputs.tf** — append:

```hcl
output "app_service_id" {
  description = "Resource ID of the web app (for diagnostics and alerts)."
  value       = azurerm_linux_web_app.this.id
}
```

## 2. Root main.tf — add the module call

```hcl
module "monitoring" {
  source              = "./modules/monitoring"
  project_name        = "webapp-demo-molly"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sql_server_id   = module.database.sql_server_id
  sql_database_id = module.database.database_id
  app_service_id  = module.app.app_service_id

  alert_email = "mollymlindquist@gmail.com"
}
```

## 3. Root outputs.tf — optional but useful

```hcl
output "log_analytics_workspace" {
  description = "Workspace name for KQL queries."
  value       = module.monitoring.workspace_name
}

# And the one that was missed earlier:
output "app_name" {
  description = "Name of the web app (for deployment commands)."
  value       = module.app.app_name
}
```

## 4. Remove the tfsec annotation — the payoff

In `modules/database/main.tf`, delete the deferral comment block and the
`#tfsec:ignore:azure-database-enable-audit` line above the
`azurerm_mssql_server` resource. The auditing policy now genuinely
exists.

Honest caveat: tfsec's static analysis usually detects the
`azurerm_mssql_server_extended_auditing_policy` resource even though it
lives in a different module, but cross-module reference resolution is
not guaranteed in every tfsec version. If the pipeline still flags the
finding after removal, re-add the annotation with an updated reason
("auditing enabled in monitoring module; tfsec cross-module resolution
limitation") — the finding is factually closed either way, and the
README can say so.

## 5. Azure Policy — one-time elevated bootstrap (run as YOU, not the SP)

Run once with your own `az login` credentials, like the state storage
bootstrap. Both use built-in policy definitions, scoped to the project
resource group.

```powershell
$rg = az group show --name rg-webapp-demo --query id -o tsv

# Policy 1: require a 'project' tag on resources in the RG
az policy assignment create `
  --name "require-project-tag" `
  --display-name "Require project tag on resources" `
  --policy "871b6d14-10aa-478d-b590-94f262ecfa99" `
  --params '{ \"tagName\": { \"value\": \"project\" } }' `
  --scope $rg

# Policy 2: deny public IPs on network interfaces in the RG
az policy assignment create `
  --name "deny-nic-public-ip" `
  --display-name "Network interfaces should not have public IPs" `
  --policy "83a86a26-fd1f-447c-b59d-e51f44264114" `
  --scope $rg
```

Notes:
- The GUIDs are Azure built-in policy definition IDs (require-tag and
  deny-NIC-public-IP respectively).
- Scoping to the RG (not the subscription) keeps the blast radius to
  this project.
- Caveat to document: because Terraform destroys and recreates the RG,
  these assignments die with it — re-run this bootstrap after a full
  destroy/rebuild. That trade-off (vs. granting the pipeline policy
  rights) is deliberate; say so in the README.

## 6. Ship it

```powershell
git checkout main && git pull
git checkout -b add-monitoring-module
# place modules/monitoring/, make edits 1-4
git add .
git commit -m "Add monitoring module: Log Analytics, SQL auditing, alerts; close tfsec finding"
git push -u origin add-monitoring-module
```

Pipeline expectations on the PR run: tfsec should report the finding
GONE (11 passed, 0 ignored) — that moment is the screenshot. Plan should
show 7 to add (workspace, auditing policy, 2 diagnostic settings, action
group, 2 alerts), 0 to change, 0 to destroy.

After merge + approval + apply: run the policy bootstrap (step 5), then
test an alert if you want the full experience — hammering a nonexistent
route won't do it (404s aren't 5xx), but stopping the SQL server or
temporarily breaking the DB password app setting will produce 5xx from
/health within minutes, followed by an email.
