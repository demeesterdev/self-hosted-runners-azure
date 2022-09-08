resource "azurerm_user_assigned_identity" "aca_identity" {
  resource_group_name = azurerm_resource_group.runner_group.name
  location            = azurerm_resource_group.runner_group.location

  name = "${var.container_app_name}-identity"
}

resource "azapi_resource" "aca_env" {
  type                   = "Microsoft.App/managedEnvironments@2022-03-01"
  parent_id              = azurerm_resource_group.runner_group.id
  location               = azurerm_resource_group.runner_group.location
  name                   = "${var.container_app_name}-env"
  response_export_values = []

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
  type                   = "Microsoft.App/containerApps@2022-03-01"
  parent_id              = azurerm_resource_group.runner_group.id
  location               = azurerm_resource_group.runner_group.location
  name                   = var.container_app_name
  response_export_values = []

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
