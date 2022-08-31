# Autoscaling Self hosted runners azure

repo to create a self hosted auto scaling gihub runner on azure.  
This implementation is inspired by https://github.com/Pwd9000-ML/docker-github-runner-linux
It has some extra's not implemented in the repo/blog post:
  - uses ephemeral runners to create a clean environment
  - seperate autoscaling service

demands that led to this implementation:
 - auto scaling
 - clean environment per run
 - no added complexity in pipelines
 - runs in private vnet
 - not accesable from the internet

This repo contains:
 - github runner container definition
 - TODO: github scale controller with container definition
 - infra to run all services
   - ACR storing container images
   - TODO: Storage Account with message que
   - TODO: Container app for github runner container
   - TODO: Container app for github scale controller 




