provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "runner_group" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "runner_acr" {
  name                = var.registry_name
  resource_group_name = azurerm_resource_group.runner_group.name
  location            = azurerm_resource_group.runner_group.location
  sku                 = var.registry_sku
  admin_enabled       = false
}

resource "azurerm_container_registry_task" "runner_build_task_linux_on_pr" {
  name                  = "${var.registry_build_task_name}-linux-pr"
  container_registry_id = azurerm_container_registry.runner_acr.id
  enabled               = true
  platform {
    os = "Linux"
  }
  docker_step {
    dockerfile_path      = var.container_build_linux_dockerfile_path
    context_path         = var.container_build_linux_context
    context_access_token = var.container_build_context_access_token
    image_names          = ["${var.container_build_image_name}:${var.container_build_linux_image_tag}-{{.Run.ID}}"]
  }

  source_trigger {
    name           = "source trigger linx"
    events         = ["pullrequest"]
    repository_url = var.container_build_linux_context
    source_type    = "Github"
    branch         = "main"
    authentication {
      token      = var.container_build_context_access_token
      token_type = "PAT"
    }
  }
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
    image_names          = [
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}-{{.Run.ID}}",
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}",
      "${var.container_build_image_name}:latest"
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

resource "azurerm_container_registry_task" "runner_build_task_linux_on_demand" {
  for_each = var.container_build_linux_execute_after_apply ? {enabled = "true"} : {}
  
  name                  = "${var.registry_build_task_name}-linux-main-manual"
  container_registry_id = azurerm_container_registry.runner_acr.id
  enabled               = true

  platform {
    os = "Linux"
  }

  docker_step {
    dockerfile_path      = var.container_build_linux_dockerfile_path
    context_path         = var.container_build_linux_context
    context_access_token = var.container_build_context_access_token
    image_names          = [
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}-{{.Run.ID}}",
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}-manual",
      "${var.container_build_image_name}:${var.container_build_linux_image_tag}",
      "${var.container_build_image_name}:latest"
    ]
  }

  timer_trigger {
    name           = "source trigger linx"
    schedule       = local.runcronexpression
  }
}