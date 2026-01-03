


resource "azurerm_container_app" "cube_api" {
  name                         = "${var.env_prefix}-api-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
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
      name = "cube-conf"
      storage_name = azurerm_container_app_environment_storage.env_cube_conf.name
      storage_type = "AzureFile"
    }

    container {
      name   = "api"
      image  = local.cube_image
      cpu    = 1
      memory = "2Gi"

      volume_mounts {
        name = "cube-conf"
        path = "/cube/conf"
      }

      dynamic "env" {
        for_each = concat(var.cube_environment_variables,
          [
            { name = "CUBEJS_CUBESTORE_HOST", value = local.cubestore_router_name },
            { name = "CUBEJS_DEV_MODE", value = var.dev_mode},
          ]
        )
        content {
          name = env.value.name
          value = env.value.value
        }
      }

    }
  }

  ingress {
    target_port      = 4000
    external_enabled = true
    allow_insecure_connections = false

    dynamic "ip_security_restriction" {
      for_each = var.allowed_ips
      content {
        action = "Allow"
        ip_address_range = ip_security_restriction.value.value
        name = ip_security_restriction.value.name
      }
    }
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
