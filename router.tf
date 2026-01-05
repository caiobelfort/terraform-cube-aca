resource "azurerm_container_app" "router" {
  count = var.dev_mode ? 0 : 1

  container_app_environment_id = azurerm_container_app_environment.this.id
  name                         = "${var.env_prefix}-router-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name = "Consumption"

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
    max_replicas = 2

    volume {
      name         = "cube-cache"
      storage_name = azurerm_container_app_environment_storage.env_cube_cache.name
      storage_type = "AzureFile"
    }

    container {
      cpu    = 1
      image  = local.cubestore_image
      memory = "2Gi"
      name   = local.cubestore_router_name

      volume_mounts {
        name = "cube-cache"
        path = "/cube/data"
      }

      env {
        name  = "CUBESTORE_SERVER_NAME"
        value = "${local.cubestore_router_name}:9999"
      }
      env {
        name  = "CUBESTORE_META_PORT"
        value = 9999
      }
      env {
        name  = "CUBESTORE_REMOTE_DIR"
        value = "/cube/data"
      }
      env {
        name  = "CUBESTORE_WORKERS"
        value = local.cubestore_workers_str
      }

      env {
        name  = "CUBESTORE_LOG_LEVEL"
        value = "trace"
      }
      env {
        name = "CUBESTORE_TELEMETRY"
        value = "false"
      }
    }

  }

  ingress {
    external_enabled = false
    target_port      = 3031
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

}

resource "azapi_update_resource" "router_port_update" {
  count = var.dev_mode ? 0 : 1
  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = azurerm_container_app.router[count.index].id

  body = {
    properties = {
      configuration = {
        ingress = {
          additionalPortMappings = [
            {
              targetPort = 9999
              exposedPort = 9999
              external   = false
            },
            {
              targetPort = 3036
              exposedPort = 3036
              external   = false
            },
            {
              targetPort = 3030
              exposedPort = 3030
              external   = false
            }
          ]
        }
      }
    }
  }
}
