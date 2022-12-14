resource_group_name                   = "demapp-ghrunner-demo"
location                              = "west europe"
registry_name                         = "demappghrunnerdemoacr"
registry_agent_pool_tier              = "S2"
registry_build_task_name              = "ghrunner-build"
container_build_image_name            = "ghrunner"
container_build_linux_context         = "https://github.com/demeesterdev/self-hosted-runners-azure#main:dockerfiles/linux-runner"
container_build_linux_dockerfile_path = "dockerfile"
container_build_linux_image_tag       = "linux"
container_app_name                    = "demappghrunnerdemo-aca"
registry_agent_pool_name              = "registry-agent-pool"
runner_labels                         = "demeesterapp-internal,awesome-runner"