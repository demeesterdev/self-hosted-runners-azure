resource "azurerm_resource_group" "runner_group" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.container_app_name}-law"
  resource_group_name = azurerm_resource_group.runner_group.name
  location            = azurerm_resource_group.runner_group.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
}
