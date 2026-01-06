resource "azurerm_container_app" "router" {
  count = var.dev_mode ? 0 : 1

  container_app_environment_id = azurerm_container_app_environment.this.id
  name                         = local.router_name
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
      name         = "cube-cache"
      storage_name = azurerm_container_app_environment_storage.env_cube_cache.name
      storage_type = "AzureFile"
    }

    container {
      cpu    = 2
      image  = local.cubestore_image
      memory = "4Gi"
      name   = local.router_name

      volume_mounts {
        name = "cube-cache"
        path = local.cache_remote_dir
      }

      env {
        name  = "CUBESTORE_SERVER_NAME"
        value = "${local.router_name}:9999"
      }
      env {
        name  = "CUBESTORE_META_PORT"
        value = "9999"
      }
      env {
        name  = "CUBESTORE_REMOTE_DIR"
        value = local.cache_remote_dir
      }
      env {
        name  = "CUBESTORE_WORKERS"
        value = local.workers_str
      }

      env {
        name  = "CUBESTORE_LOG_LEVEL"
        value = "trace"
      }
      env {
        name = "CUBESTORE_TELEMETRY"
        value = "false"
      }

      env {
        name = "VERSION"
        value = local.env_version
      }

      env {
        name = "NODE_OPTIONS"
        value = "--max-old-space-size=6144"
      }
    }

  }

  ingress {
    external_enabled = false
    target_port      = 9999
    exposed_port = 9999
    transport = "tcp"
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
              targetPort = 3031
              exposedPort = 3031
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
