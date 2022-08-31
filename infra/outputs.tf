output "registry_id" {
  value = azurerm_container_registry.runner_acr.id
}

output "registry_login_server" {
  value = azurerm_container_registry.runner_acr.login_server
}

output "container_build_excute_time" {
    description = "time at wich the acr task run if execute after apply variable is set to true"
    value = local.runtimestamp
}