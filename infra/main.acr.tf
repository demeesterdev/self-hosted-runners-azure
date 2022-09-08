
resource "azurerm_container_registry" "runner_acr" {
  name                          = var.registry_name
  resource_group_name           = azurerm_resource_group.runner_group.name
  location                      = azurerm_resource_group.runner_group.location
  sku                           = "Premium"
  admin_enabled                 = true
  public_network_access_enabled = false
}

resource "azurerm_role_assignment" "container_app_access" {
  scope                = azurerm_container_registry.runner_acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca_identity.principal_id
}


resource "azurerm_container_registry_task" "runner_build_task_linux" {
  name                  = "${var.registry_build_task_name}-linux-tfapply"
  container_registry_id = azurerm_container_registry.runner_acr.id
  enabled               = true
  agent_pool_name       = azurerm_container_registry_agent_pool.runner_acr_pool.name
  platform {
    os = "Linux"
  }
  docker_step {
    dockerfile_path      = var.container_build_linux_dockerfile_path
    context_path         = var.container_build_linux_context
    context_access_token = var.container_build_context_access_token
    image_names = [
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}-{{.Run.ID}}",
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}-tf-apply",
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}",
    ]
  }
}

resource "azurerm_container_registry_agent_pool" "runner_acr_pool" {
  name                          = "runner-agent-pool"
  resource_group_name           = azurerm_resource_group.runner_group.name
  location                      = azurerm_resource_group.runner_group.location
  container_registry_name       = azurerm_container_registry.runner_acr.name
  virtual_network_subnet_id     = azurerm_subnet.acr.id
}

resource "azurerm_container_registry_task_schedule_run_now" "runner_build_task_linux" {
  container_registry_task_id = azurerm_container_registry_task.runner_build_task_linux.id
}

resource "azurerm_private_endpoint" "runner_acr" {
  name                = "${var.container_app_name}-acr-endpoint"
  resource_group_name = azurerm_resource_group.runner_group.name
  location            = azurerm_resource_group.runner_group.location
  subnet_id           = azurerm_subnet.acr.id

  private_service_connection {
    name                           = "${var.container_app_name}-acr-privateserviceconnection"
    private_connection_resource_id = azurerm_container_registry.runner_acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name = "PR-ACR-DNS-zone-group"
    private_dns_zone_ids = [ azurerm_private_dns_zone.privatelink_azurecr_io.id ]
  }   
}

