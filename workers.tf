locals {
  worker_resources = {
    small = {
      cpu    = 1
      memory = "2Gi"
    }
    medium = {
      cpu    = 2
      memory = "4Gi"
    }
    large = {
      cpu    = 4
      memory = "8Gi"
    }
  }
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [azurerm_container_app.router, azapi_update_resource.router_port_update]
  create_duration = "60s"
}


resource "azurerm_container_app" "cubestore_worker" {
  count                        = var.dev_mode ? 0 : var.num_workers
  name                         = local.worker_names[count.index]
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  depends_on = [time_sleep.wait_60_seconds]

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
      name = "cube-cache"
      storage_name = azurerm_container_app_environment_storage.env_cube_cache.name
      storage_type = "AzureFile"
    }

    container {
      name   = local.worker_names[count.index]
      image  = local.cubestore_image
      cpu    = local.worker_resources[var.worker_size].cpu
      memory = local.worker_resources[var.worker_size].memory

      volume_mounts {
        name = "cube-cache"
        path = local.cache_remote_dir
      }

      env {
        name  = "CUBESTORE_META_ADDR"
        value = "${local.router_name}:9999"
      }

      env {
        name  = "CUBESTORE_SERVER_NAME"
        value = "${local.worker_names[count.index]}:${10001 + count.index}"
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
        name  = "CUBESTORE_WORKER_PORT"
        value = 10001 + count.index
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
    target_port      = 10001 + count.index
    exposed_port = 10001 + count.index
    transport = "tcp"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

resource "azapi_update_resource" "workers_port_update" {
  count       = var.dev_mode ? 0 : var.num_workers
  type        = "Microsoft.App/containerApps@2025-01-01"
  resource_id = azurerm_container_app.cubestore_worker[count.index].id

  body = {
    properties = {
      configuration = {
        ingress = {
          additionalPortMappings = [
            {
              targetPort  = 3031
              exposedPort = 3031
              external    = false
            }
          ]
        }
      }
    }
  }
}







