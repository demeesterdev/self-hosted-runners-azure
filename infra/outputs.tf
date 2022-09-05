output "registry_id" {
  value = azurerm_container_registry.runner_acr.id
}

output "registry_login_server" {
  value = azurerm_container_registry.runner_acr.login_server
}