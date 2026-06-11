

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

resource "azurerm_resource_group" "this" {
  location = var.location
  name     = "${var.env_prefix}-rg-${var.location}-${var.suffix}"
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.env_prefix}-logs-${var.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}



resource "azurerm_container_app_environment" "this" {
  name                       = "${var.env_prefix}-environment-${var.suffix}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }

}

# Creates an identity to setup the container app to access the ACR if identity type is 'SystemAssigned'
resource "azurerm_user_assigned_identity" "identity" {
  count = local.use_sp ? 0 : 1

  name                = "${var.env_prefix}-indentity-${var.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

# Setups a role if identity type is 'SystemAssigned'
resource "azurerm_role_assignment" "acr_permission" {
  count = local.use_sp ? 0 : 1

  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.identity[0].principal_id

  depends_on = [azurerm_user_assigned_identity.identity]

}

locals {
  acr_server      = data.azurerm_container_registry.acr.login_server
  cubestore_image = "${local.acr_server}/${var.cubestore_image}"
  cube_image      = "${local.acr_server}/${var.cube_image}"
  router_name     = "cubestorerouter"
  worker_names = [
    for i in range(var.num_workers) :
    "cubestoreworker${i + 1}"
  ]
  workers_str      = join(",", [for i in range(var.num_workers) : "${local.worker_names[i]}:${10001 + i}"])
  cache_remote_dir = "/cube/data"

  env_version = formatdate("YYYYMMDDhhmmss", timestamp())

  use_sp = var.identity_type == "ServicePrincipal"
}
