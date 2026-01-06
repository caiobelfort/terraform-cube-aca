resource "azurerm_container_app" "refresher" {
  count = var.dev_mode ? 0 : 1

  container_app_environment_id = azurerm_container_app_environment.this.id
  name                         = "cube-refresh-worker"
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.identity.id]
  }

  registry {
    server   = local.acr_server
    identity = azurerm_user_assigned_identity.identity.id
  }



  template {
    min_replicas = 1
    max_replicas = 1


    volume {
      name         = "cube-conf"
      storage_name = azurerm_container_app_environment_storage.env_cube_conf.name
      storage_type = "AzureFile"
    }

    container {
      cpu    = 2
      image  = local.cube_image
      memory = "4Gi"
      name   = "refresher"

      volume_mounts {
        name = "cube-conf"
        path = "/cube/conf"
      }

      dynamic "env" {
        # Add specific refresh worker variable
        for_each = concat(var.cube_environment_variables,
          [
            { name = "CUBEJS_REFRESH_WORKER", value = true},
            { name = "CUBEJS_CUBESTORE_HOST", value = local.router_name},
            { name = "VERSION", value = local.env_version}
          ])
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
    }
  }
}
