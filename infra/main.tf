resource "azurerm_resource_group" "runner_group" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "runner_acr" {
  name                = var.registry_name
  resource_group_name = azurerm_resource_group.runner_group.name
  location            = azurerm_resource_group.runner_group.location
  sku                 = var.registry_sku
  admin_enabled       = true
}

resource "azurerm_container_registry_task" "runner_build_task_linux_on_main" {
  name                  = "${var.registry_build_task_name}-linux-main-commit"
  container_registry_id = azurerm_container_registry.runner_acr.id
  enabled               = true
  platform {
    os = "Linux"
  }
  docker_step {
    dockerfile_path      = var.container_build_linux_dockerfile_path
    context_path         = var.container_build_linux_context
    context_access_token = var.container_build_context_access_token
    image_names = [
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}-{{.Run.ID}}",
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}-auto",
    ]
  }

  source_trigger {
    name           = "source trigger linx"
    events         = ["commit"]
    repository_url = var.container_build_linux_context
    source_type    = "Github"
    branch         = "main"
    authentication {
      token      = var.container_build_context_access_token
      token_type = "PAT"
    }
  }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.container_app_name}-law"
  resource_group_name = azurerm_resource_group.runner_group.name
  location            = azurerm_resource_group.runner_group.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
}

resource "azapi_resource" "aca_env" {
  type      = "Microsoft.App/managedEnvironments@2022-03-01"
  parent_id = azurerm_resource_group.runner_group.id
  location  = azurerm_resource_group.runner_group.location
  name      = "${var.container_app_name}-env"

  body = jsonencode({
    properties = {
      appLogsConfiguration = {
        destination = "log-analytics"
        logAnalyticsConfiguration = {
          customerId = azurerm_log_analytics_workspace.law.workspace_id
          sharedKey  = azurerm_log_analytics_workspace.law.primary_shared_key
        }
      }
    }
  })
}

# resource "azapi_resource" "aca" {
#   type = "Microsoft.App/containerApps@2022-03-01"
#   parent_id = azurerm_resource_group.runner_group.id
#   location = azurerm_resource_group.runner_group.location
#   name = var.container_app_name
  
#   body = jsonencode({
#     properties = {
#     managedEnvironmentId = azapi_resource.aca_env.id
#       configuration = {
#         ingress = {
#           external = false
#         }

#       }
#     }
#   })
# }