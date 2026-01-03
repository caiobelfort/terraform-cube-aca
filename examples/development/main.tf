terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.56.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = ">=2.8.0"
    }
  }
}
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

provider "azapi" {}


module "cube" {
  source = "../.."
  subscription_id = var.subscription_id
  env_prefix = "cubeex"
  acr_name                = var.acr_name
  acr_resource_group_name = var.acr_resource_group_name
  allowed_ips = var.allowed_ips
  location = "eastus2"
  cube_image = var.cube_image
  cubestore_image = var.cubestore_image
  cube_environment_variables = var.cube_envs
  cube_files_dir = "./cube"
  dev_mode = true # -->> This variable setups a dev environment with playground
}

