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
      vnetConfiguration = {
        #dockerBridgeCidr: 'string'
        infrastructureSubnetId = azurerm_subnet.aca.id #ID of subnet ACA -> Resource ID of a subnet for infrastructure components
        internal               = true
        #platformReservedCidr: 'string'
        #platformReservedDnsIP: 'string'
        runtimeSubnetId = azurerm_subnet.aca_runtime.id #ID of subnet ACA runtine -> Resource ID of a subnet that Container App containers are injected into. This subnet must be in the same VNET as the subnet defined in infrastructureSubnetId.
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
            name  = "github-runner-pat-token"
            value = var.runner_registration_token
          },
          {
            name  = "github-runner-organization"
            value = var.runner_organization_name
          },
          {
            name  = "github-runner-application-id"
            value = var.runner_app_id
          },
          {
            name  = "github-runner-application-secret"
            value = var.runner_app_secret
          },
          {
            name  = "github-runner-labels"
            value = var.runner_labels
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
                name      = "RUNNER_ORGANIZATION"
                secretRef = "github-runner-organization"
              },
              {
                name      = "RUNNER_PAT"
                secretRef = "github-runner-pat-token"
              },
              {
                name      = "RUNNER_APP_ID"
                secretRef = "github-runner-application-id"
              },
              {
                name      = "RUNNER_APP_SECRET"
                secretRef = "github-runner-application-secret"
              },
              {
                name      = "RUNNER_LABELS"
                secretRef = "github-runner-labels"
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

# resource "azurerm_private_endpoint" "runner_aca" {
#   name = "${var.container_app_name}-aca-endpoint"
#   resource_group_name = azurerm_resource_group.runner_group.name
#   location = azurerm_resource_group.runner_group.location
#   subnet_id = azurerm_subnet.aca.id

#   private_service_connection {
#     name  = "${var.container_app_name}-aca-privateserviceconnection"
#     private_connection_resource_id = azapi_resource.aca_env.id
#     is_manual_connection = "false"
#     subresource_names = [""]
#   }
# }
