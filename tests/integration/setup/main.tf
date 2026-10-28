# A resource group, a virtual network (with AzureBastionSubnet unless turned off) and a Log Analytics
# workspace for one integration test run.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "bastion_subnet" {
  type    = bool
  default = true
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Sweden Central has Bastion Developer and Bastion availability zones (Microsoft Learn, 2026-10-28).
resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-bas-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = "swedencentral"
}

resource "azapi_resource" "virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  name      = "vnet-mlz-bas-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.0.0.0/24"] }
    }
  }
}

resource "azapi_resource" "bastion_subnet" {
  count = var.bastion_subnet ? 1 : 0

  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = "AzureBastionSubnet"
  parent_id = azapi_resource.virtual_network.id
  body = {
    properties = { addressPrefixes = ["10.0.0.0/26"] }
  }
}

resource "azapi_resource" "workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  name      = "log-mlz-bas-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = azapi_resource.resource_group.location
  body = {
    properties = {
      retentionInDays = 30
      sku             = { name = "PerGB2018" }
    }
  }
}

output "bastion_subnet_id" {
  value = one(azapi_resource.bastion_subnet[*].id)
}

output "location" {
  value = azapi_resource.resource_group.location
}

output "object_id" {
  value = data.azapi_client_config.current.object_id
}

output "resource_group_id" {
  value = azapi_resource.resource_group.id
}

output "suffix" {
  value = random_string.suffix.result
}

output "virtual_network_id" {
  value = azapi_resource.virtual_network.id
}

output "workspace_id" {
  value = azapi_resource.workspace.id
}
