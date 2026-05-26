resource "azurerm_container_app" "refresher" {
  count = var.dev_mode ? 0 : 1

  container_app_environment_id = azurerm_container_app_environment.this.id
  name                         = "cube-refresh-worker"
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

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
