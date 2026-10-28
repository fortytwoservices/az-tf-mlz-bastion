# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  tags     = { example = "default" }
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

resource "azapi_resource" "bastion_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "AzureBastionSubnet"
  parent_id = azapi_resource.virtual_network.id
  body = {
    properties = {
      addressPrefixes = ["10.0.0.0/26"]
    }
  }

  response_export_values = []
}

resource "azapi_resource" "workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  name      = "log-mlz-bas-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      retentionInDays = 30
      sku             = { name = "PerGB2018" }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

module "bastion" {
  source = "../../"

  name      = "bas-mlz-bas-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  ip_configuration = {
    subnet_id = azapi_resource.bastion_subnet.id
    public_ip = { name = "pip-mlz-bas-${random_string.suffix.result}" }
  }
  tunneling_enabled  = true
  ip_connect_enabled = true
  diagnostic_settings = {
    workspace = {
      workspace_resource_id = azapi_resource.workspace.id
      logs                  = [{ category_group = "allLogs" }]
      metrics               = [{ category = "AllMetrics" }]
    }
  }
  tags = local.tags
}
