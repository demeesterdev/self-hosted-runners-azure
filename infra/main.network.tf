
resource "azurerm_virtual_network" "ghrunnervnet" {
  name                = "${var.container_app_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.runner_group.name
  location            = azurerm_resource_group.runner_group.location
}

resource "azurerm_subnet" "default" {
  name                 = "default-subnet"
  resource_group_name  = azurerm_resource_group.runner_group.name
  virtual_network_name = azurerm_virtual_network.ghrunnervnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "acr" {
  name                                      = "${var.container_app_name}-acr-subnet"
  resource_group_name                       = azurerm_resource_group.runner_group.name
  virtual_network_name                      = azurerm_virtual_network.ghrunnervnet.name
  address_prefixes                          = ["10.0.2.0/24"]
  private_endpoint_network_policies_enabled = false
}

resource "azurerm_subnet" "aca" {
  name                                      = "${var.container_app_name}-aca-subnet"
  resource_group_name                       = azurerm_resource_group.runner_group.name
  virtual_network_name                      = azurerm_virtual_network.ghrunnervnet.name
  address_prefixes                          = ["10.0.4.0/23"] #next available is 10.0.6.0/x
  private_endpoint_network_policies_enabled = false
}

resource "azurerm_private_dns_zone" "privatelink_azurecr_io" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.runner_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "privatelink.azurecr.io"
  resource_group_name   = azurerm_resource_group.runner_group.name
  private_dns_zone_name = azurerm_private_dns_zone.privatelink_azurecr_io.name
  virtual_network_id    = azurerm_virtual_network.ghrunnervnet.id
}