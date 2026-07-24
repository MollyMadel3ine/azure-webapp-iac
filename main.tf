# ------------------------------------------------------------------
# Example: how your root main.tf calls the network module.
# This file lives at the repo root (not inside modules/).
# ------------------------------------------------------------------

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      #       source  = "hashicorp/random"
      #       version = "~> 3.6"
      #     }
    }
  }

  # Remote state — the detail that signals team-workflow awareness.
  # Create the storage account once (CLI or a tiny bootstrap config),
  # then every plan/apply locks and shares state automatically.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatemolly" # must be globally unique
    container_name       = "tfstate"
    key                  = "webapp-demo.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-webapp-demo"
  location = "westus2"
}

module "network" {
  source              = "./modules/network"
  project_name        = "webapp-demo"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Defaults cover the rest, but you can override:
  # vnet_address_space = "10.10.0.0/16"
  # web_subnet_prefix  = "10.10.1.0/24"
  # data_subnet_prefix = "10.10.2.0/24"
}

# Database module
module "database" {
  source              = "./modules/database"
  project_name        = "webapp-demo-molly" # sql server names are GLOBALLY unique — make this yours
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Wired straight from the network module's outputs — this is the
  # modular contract paying off.
  vnet_id        = module.network.vnet_id
  data_subnet_id = module.network.data_subnet_id

  # Defaults: username sqladminuser, database appdb, Basic sku.
  # Override here if you want:
  # database_sku = "GP_S_Gen5_1"  # serverless, auto-pauses when idle
}

# Later, the app module will plug in like this:
#
# module "app" {
#   source        = "./modules/app"
#   web_subnet_id = module.network.web_subnet_id
#   ...
# }

#App module
module "app" {
  source              = "./modules/app"
  project_name        = "webapp-demo-molly" # app URL is global: <this>-app.azurewebsites.net
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Network module output — the delegated web subnet
  web_subnet_id = module.network.web_subnet_id

  # Database module outputs — the app's connection details
  db_server_fqdn = module.database.sql_server_fqdn
  db_name        = module.database.database_name
  db_username    = module.database.sql_admin_username
  db_password    = module.database.sql_admin_password
}

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
