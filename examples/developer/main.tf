# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  # Bastion Developer runs in some regions only (Microsoft Learn, SKU comparison).
  location = "swedencentral"
  tags     = { example = "developer" }
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-bas-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

resource "azapi_resource" "virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-mlz-bas-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.0.0.0/24"] }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

module "bastion" {
  source = "../../"

  name               = "bas-mlz-bas-${random_string.suffix.result}"
  parent_id          = azapi_resource.resource_group.id
  location           = local.location
  sku                = "Developer"
  virtual_network_id = azapi_resource.virtual_network.id
  tags               = local.tags
}
