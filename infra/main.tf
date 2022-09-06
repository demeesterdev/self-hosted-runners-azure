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

resource "azurerm_user_assigned_identity" "aca_identity" {
  resource_group_name = azurerm_resource_group.runner_group.name
  location            = azurerm_resource_group.runner_group.location

  name = "${var.container_app_name}-identity"
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_container_registry.runner_acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca_identity.principal_id
}

resource "azurerm_container_registry_task" "runner_build_task_linux" {
  name                  = "${var.registry_build_task_name}-linux-tfapply"
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
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}-tf-apply",
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}",
    ]
  }
}

resource "azurerm_container_registry_task_schedule_run_now" "runner_build_task_linux" {
  container_registry_task_id = azurerm_container_registry_task.runner_build_task_linux.id
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

resource "azapi_resource" "aca_ghrunner" {
  depends_on = [
    azurerm_container_registry_task_schedule_run_now.runner_build_task_linux
  ]
  type      = "Microsoft.App/containerApps@2022-03-01"
  parent_id = azurerm_resource_group.runner_group.id
  location  = azurerm_resource_group.runner_group.location
  name      = var.container_app_name
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aca_identity.id
    ]
  }

  body = jsonencode({
    properties = {
      managedEnvironmentId = azapi_resource.aca_env.id
      configuration = {
        secrets = [
          {
            name  = "github-runner-registration-token"
            value = var.runner_registration_token
          },
          {
            name  = "github-runner-organization"
            value = var.runner_organization_name
          }
        ]
        registries = [
          {
            server   = azurerm_container_registry.runner_acr.login_server
            identity = azurerm_user_assigned_identity.aca_identity.id
          }
        ]
      }
      template = {
        containers = [
          {
            name  = "github-runner"
            image = "${azurerm_container_registry.runner_acr.login_server}/${var.container_build_image_name}:${var.container_build_linux_image_tag}"
            env = [
              {
                name      = "GH_ORGANIZATION"
                secretRef = "github-runner-organization"
              },
              {
                name      = "GH_TOKEN"
                secretRef = "github-runner-registration-token"
              }
            ]
            resources = {
              cpu    = 1
              memory = "2.0Gi"
            }
          }
        ]
        scale = {
          minReplicas = 5
          maxReplicas = 5
          rules       = []
        }
      }
    }
  })
}
