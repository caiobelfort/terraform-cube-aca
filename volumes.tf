# Creates an azure storage account to setup two file shares
# One for cache and another one for project files


resource "azurerm_storage_account" "this" {
  name = "${var.env_prefix}storage${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location = azurerm_resource_group.this.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_storage_share" "conf_share" {
  name  = "${var.env_prefix}-config-share"
  storage_account_id = azurerm_storage_account.this.id
  quota = 20

}

resource "azurerm_storage_share" "cache_share" {
  name = "${var.env_prefix}-cache-share"
  storage_account_id = azurerm_storage_account.this.id
  quota = 100
}


resource "azurerm_container_app_environment_storage" "env_cube_conf" {
  name = "cube-conf"
  container_app_environment_id = azurerm_container_app_environment.this.id
  account_name = azurerm_storage_account.this.name
  share_name = azurerm_storage_share.conf_share.name
  access_key = azurerm_storage_account.this.primary_access_key
  access_mode = "ReadOnly"
}

resource "azurerm_container_app_environment_storage" "env_cube_cache" {
  name = "cube-cache"
  container_app_environment_id = azurerm_container_app_environment.this.id
  account_name = azurerm_storage_account.this.name
  share_name = azurerm_storage_share.cache_share.name
  access_key = azurerm_storage_account.this.primary_access_key
  access_mode = "ReadWrite"
}


resource terraform_data "update_cube_files" {
  depends_on = [azurerm_storage_share.conf_share]

  triggers_replace = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
      az storage file delete-batch --source ${azurerm_storage_share.conf_share.name} --account-name ${azurerm_storage_account.this.name} --account-key ${azurerm_storage_account.this.primary_access_key} --pattern "*" && \
      az storage file upload-batch --destination ${azurerm_storage_share.conf_share.name} --source ${var.cube_files_dir} --account-name ${azurerm_storage_account.this.name} --account-key ${azurerm_storage_account.this.primary_access_key}
   EOF
  }
}