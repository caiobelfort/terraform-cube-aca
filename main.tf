

data "azurerm_container_registry" "acr" {
  name = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  location = var.location
  name     = "${var.env_prefix}-rg-${var.location}-${random_string.suffix.result}"
}

resource "azurerm_log_analytics_workspace" "this" {
  name = "${var.env_prefix}-logs-${random_string.suffix.result}"
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku = "PerGB2018"
  retention_in_days = 30
}

resource "azurerm_container_app_environment" "this" {
  name = "${var.env_prefix}-environment-${random_string.suffix.result}"
  location = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  workload_profile {
    minimum_count = 0
    maximum_count = 0
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

}

# Creates an identity to setup the container app to access the ACR
resource "azurerm_user_assigned_identity" "identity" {
  name                = "${var.env_prefix}-indentity-${random_string.suffix.result}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "acr_permission" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id

  depends_on = [azurerm_user_assigned_identity.identity]

}

locals {
  acr_server      = data.azurerm_container_registry.acr.login_server
  cubestore_image = "${local.acr_server}/${var.cubestore_image}"
  cube_image      = "${local.acr_server}/${var.cube_image}"
  cubestore_router_name = "${var.env_prefix}-router-${random_string.suffix.result}"
  worker_names = [
    for i in range(var.num_workers) :
    "${var.env_prefix}-worker-${i}-${random_string.suffix.result}"
  ]
  cubestore_workers_str = join(",", [for i in range(var.num_workers) : "${local.worker_names[i]}:${10001 + i}"])
  merged_envs = concat(
    var.cube_environment_variables, [
      {
        name = "CUBEJS_DEV_MODE"
        value = var.dev_mode
      },
      {
        name = "CUBEJS_CUBESTORE_HOST"
        value = local.cubestore_router_name
      }
    ]
  )
}







