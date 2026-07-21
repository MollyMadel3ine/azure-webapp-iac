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
#
