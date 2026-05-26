resource "azurerm_container_app" "cube_api" {
  name                         = "cube-api"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"

  depends_on = [azurerm_container_app.refresher, azurerm_container_app.cubestore_worker]

  # Use managed identity for ACR pull when not using Service Principal
  dynamic "identity" {
    for_each = local.use_sp ? [] : [1]
    content {
      type         = "UserAssigned"
      identity_ids = [azurerm_user_assigned_identity.identity[0].id]
    }
  }

  # Store SP secret for ACR authentication
  dynamic "secret" {
    for_each = local.use_sp && var.sp_secret != null ? [1] : []
    content {
      name  = "acr-password"
      value = var.sp_secret
    }
  }

  # ACR registry auth via managed identity
  dynamic "registry" {
    for_each = local.use_sp ? [] : [1]
    content {
      server   = local.acr_server
      identity = azurerm_user_assigned_identity.identity[0].id
    }
  }

  # ACR registry auth via Service Principal credentials
  dynamic "registry" {
    for_each = local.use_sp ? [1] : []
    content {
      server               = local.acr_server
      username             = var.sp_id
      password_secret_name = "acr-password"
    }
  }

  template {
    min_replicas = var.cube_api_scale.min_size
    max_replicas = var.cube_api_scale.max_size

    volume {
      name         = "cube-conf"
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
            { name = "CUBEJS_CUBESTORE_HOST", value = local.router_name },
            { name = "CUBEJS_DEV_MODE", value = var.dev_mode },
            { name = "VERSION", value = local.env_version }
          ]
        )
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
    }
  }

  ingress {
    target_port                = 4000
    external_enabled           = true
    allow_insecure_connections = false

    dynamic "ip_security_restriction" {
      for_each = var.allowed_ips
      content {
        action           = "Allow"
        ip_address_range = ip_security_restriction.value.value
        name             = ip_security_restriction.value.name
      }
    }

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
