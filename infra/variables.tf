variable "resource_group_name" {
  type        = string
  description = "name for the resourcegroup deploying to"
  nullable    = false
}

variable "location" {
  type        = string
  description = "Azure region to deploy resources to"
  nullable    = false
}

variable "registry_name" {
  type        = string
  description = "name for the registry about to be deployed"
  nullable    = false
}

variable "registry_build_task_name" {
  type        = string
  description = "name for the runner build task in acr"
}

variable "registry_agent_pool_name" {
  type        = string
  description = "name for the registry agent pool"
}

variable "registry_agent_pool_tier" {
  type        = string
  description = "name for the registry agent pool"
  default     = "S1"
}

variable "container_build_image_name" {
  type        = string
  description = "name for the container image"
}

variable "container_build_linux_context" {
  type        = string
  description = "build context url for the linux build. see https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tasks-overview#context-locations for more information"
}


variable "container_build_linux_dockerfile_path" {
  type        = string
  description = "location in context where to find the dockerfile"
}

variable "container_build_linux_image_tag" {
  type        = string
  description = "tag used for the container build image under linux"
}

variable "container_build_context_access_token" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "The token (Git PAT or SAS token of storage account blob) associated with the context for this step."
}

variable "container_build_linux_execute_after_apply" {
  type        = bool
  nullable    = false
  default     = false
  description = "Add a step to rebuild the container after tf apply. added for development."
}

variable "container_app_name" {
  type        = string
  description = "Name for the container app"
  nullable    = false
}

variable "runner_registration_token" {
  type        = string
  sensitive   = true
  description = "token used by the runner to register itself"
}

variable "runner_organization_name" {
  type        = string
  description = "organization used by the runner for registration"
}
