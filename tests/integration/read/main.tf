# Reads a bastion host straight from Azure, to check what the module sent reached it.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "bastion_id" {
  type = string
}

data "azapi_resource" "bastion" {
  type                   = "Microsoft.Network/bastionHosts@2025-07-01"
  resource_id            = var.bastion_id
  response_export_values = ["properties", "sku", "zones"]
}

output "properties" {
  value = data.azapi_resource.bastion.output.properties
}

output "sku" {
  value = data.azapi_resource.bastion.output.sku.name
}

output "zones" {
  value = try(data.azapi_resource.bastion.output.zones, null)
}
