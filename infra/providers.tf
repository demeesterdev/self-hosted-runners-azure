terraform {
  required_version = "1.2.9"
  backend "azurerm" {
    resource_group_name  = "demapp-ghrunner-demo-state"
    storage_account_name = "demappghrunnertfstate"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.21.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>0.5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}