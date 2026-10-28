variable "location" {
  type        = string
  description = "Azure region of the bastion host and of the public IP address the module creates, for example `swedencentral`."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the bastion host."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9_.-]{0,78}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, underscores, periods and hyphens, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group the bastion host and the public IP address the module creates are created in."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "copy_paste_enabled" {
  type        = bool
  default     = true
  description = "Copy and paste in web-based sessions. Turning it off needs `Standard` or `Premium`."
  nullable    = false

  validation {
    condition     = var.copy_paste_enabled || contains(["Standard", "Premium"], var.sku)
    error_message = "Copy and paste can be turned off only on `Standard` and `Premium`."
  }
}

variable "file_copy_enabled" {
  type        = bool
  default     = false
  description = "Uploading and downloading files in native client sessions. `Standard` or `Premium`."
  nullable    = false

  validation {
    condition     = !var.file_copy_enabled || contains(["Standard", "Premium"], var.sku)
    error_message = "`file_copy_enabled` needs `Standard` or `Premium`."
  }
}

variable "ip_configuration" {
  type = object({
    subnet_id = string
    name      = optional(string, "ipconfig")
    public_ip = optional(object({
      name                = string
      public_ip_prefix_id = optional(string)
    }))
    public_ip_resource_id = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
(Optional) Where a `Basic`, `Standard` or `Premium` bastion host sits: required for those tiers, not taken by `Developer`. The subnet belongs to the caller (the hub composition creates it). Changing any of these replaces the bastion host.

- `subnet_id` - Resource ID of the virtual network's `AzureBastionSubnet` (/26 or larger).
- `name` - (Optional) Name of the IP configuration. Defaults to `ipconfig`.
- `public_ip` - (Optional) A public IP address the module creates through `az-tf-mlz-public-ip`: `name`, and optionally `public_ip_prefix_id` to take it from a prefix. With `zones` set it is zone-redundant (zones `1`, `2` and `3`), as Azure requires; otherwise its zones are left to Azure, which makes it zone-redundant where the region has zones.
- `public_ip_resource_id` - (Optional) An existing Standard public IP address with static allocation instead.

Exactly one of `public_ip` and `public_ip_resource_id`; neither with `private_only_enabled`. Which address is created depends only on which one is set, so its name may be unknown until apply.
DESCRIPTION

  validation {
    condition     = (var.ip_configuration == null) == (var.sku == "Developer")
    error_message = "`ip_configuration` is required for `Basic`, `Standard` and `Premium`, and not taken by `Developer` (which takes `virtual_network_id`)."
  }
  validation {
    condition     = var.ip_configuration == null ? true : lower(try(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", var.ip_configuration.subnet_id).name, "")) == "azurebastionsubnet"
    error_message = "`ip_configuration.subnet_id` must be the resource ID of a subnet named `AzureBastionSubnet`."
  }
  validation {
    condition     = var.ip_configuration == null ? true : var.private_only_enabled ? var.ip_configuration.public_ip == null && var.ip_configuration.public_ip_resource_id == null : (var.ip_configuration.public_ip == null) != (var.ip_configuration.public_ip_resource_id == null)
    error_message = "`ip_configuration` needs exactly one of `public_ip` (created) and `public_ip_resource_id` (existing), and neither with `private_only_enabled`."
  }
  validation {
    condition     = var.ip_configuration == null ? true : var.ip_configuration.public_ip_resource_id == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/publicIPAddresses", var.ip_configuration.public_ip_resource_id))
    error_message = "`ip_configuration.public_ip_resource_id` must be a public IP address resource ID."
  }
}

variable "ip_connect_enabled" {
  type        = bool
  default     = false
  description = "Connecting to a virtual machine by its private IP address (IP-based connection). `Standard` or `Premium`."
  nullable    = false

  validation {
    condition     = !var.ip_connect_enabled || contains(["Standard", "Premium"], var.sku)
    error_message = "`ip_connect_enabled` needs `Standard` or `Premium`."
  }
}

variable "ip_rules" {
  type        = list(string)
  default     = []
  description = "IP access control list of a `Developer` bastion host (`networkAcls.ipRules`): IPv4 addresses or ranges in CIDR notation, for example `[\"203.0.113.0/24\"]`. `Developer` only."
  nullable    = false

  validation {
    condition     = length(var.ip_rules) == 0 || var.sku == "Developer"
    error_message = "`ip_rules` are taken only by `Developer`."
  }
  validation {
    condition     = alltrue([for rule in var.ip_rules : can(cidrnetmask(strcontains(rule, "/") ? rule : "${rule}/32"))])
    error_message = "Each of `ip_rules` must be an IPv4 address or an IPv4 range in CIDR notation."
  }
}

variable "kerberos_enabled" {
  type        = bool
  default     = false
  description = "Kerberos authentication. `Basic`, `Standard` or `Premium`: Learn's SKU comparison lists it for `Developer` too, but Azure rejects every feature property on a `Developer` bastion host (`FeatureNotSupportedForDeveloperBastionSku`)."
  nullable    = false

  validation {
    condition     = !var.kerberos_enabled || var.sku != "Developer"
    error_message = "`kerberos_enabled` needs `Basic`, `Standard` or `Premium`: Azure takes no feature settings on `Developer`."
  }
}

variable "private_only_enabled" {
  type        = bool
  default     = false
  description = "A private-only bastion host, without a public IP address, reached only over private connectivity. `Premium` only. Azure sets it only when it creates the bastion host, so changing it replaces the bastion host."
  nullable    = false

  validation {
    condition     = !var.private_only_enabled || var.sku == "Premium"
    error_message = "`private_only_enabled` needs `Premium`."
  }
}

variable "scale_units" {
  type        = number
  default     = 2
  description = "Number of instances, 2 to 50. More than 2 needs `Standard` or `Premium`; `Basic` always has 2, and `Developer` is shared."
  nullable    = false

  validation {
    condition     = var.scale_units >= 2 && var.scale_units <= 50 && floor(var.scale_units) == var.scale_units
    error_message = "`scale_units` must be a whole number from 2 to 50."
  }
  validation {
    condition     = var.scale_units == 2 || contains(["Standard", "Premium"], var.sku)
    error_message = "More than 2 `scale_units` needs `Standard` or `Premium`."
  }
}

variable "session_recording_enabled" {
  type        = bool
  default     = false
  description = "Graphical session recording. `Premium` only. The storage container for the recordings is set on the bastion host in the portal, not by this module, and native client sessions are not recorded (Microsoft Learn, session recording)."
  nullable    = false

  validation {
    condition     = !var.session_recording_enabled || var.sku == "Premium"
    error_message = "`session_recording_enabled` needs `Premium`."
  }
}

variable "shareable_link_enabled" {
  type        = bool
  default     = false
  description = "Shareable links, which let users without portal access connect to a virtual machine. `Standard` or `Premium`."
  nullable    = false

  validation {
    condition     = !var.shareable_link_enabled || contains(["Standard", "Premium"], var.sku)
    error_message = "`shareable_link_enabled` needs `Standard` or `Premium`."
  }
}

variable "sku" {
  type        = string
  default     = "Standard"
  description = "Tier of the bastion host (Microsoft Learn, \"Choose the right Azure Bastion SKU\"): `Developer` (free, shared, one connection at a time, no peered virtual networks, in some regions only; takes `virtual_network_id`), or a dedicated host in `AzureBastionSubnet` (takes `ip_configuration`): `Basic`, `Standard` (scaling, native client, file copy, IP-based connection, shareable links) or `Premium` (also session recording and private-only). `Basic`, `Standard` and `Premium` upgrade in place; Azure supports no downgrade, so a lower tier needs the bastion host replaced (`-replace` on its `azapi_resource.this`). Changing between `Developer` and the other tiers replaces it."
  nullable    = false

  validation {
    condition     = contains(["Developer", "Basic", "Standard", "Premium"], var.sku)
    error_message = "`sku` must be `Developer`, `Basic`, `Standard` or `Premium`."
  }
}

variable "tunneling_enabled" {
  type        = bool
  default     = false
  description = "Native client support: connections from the Azure CLI (`az network bastion ssh`, `rdp` and `tunnel`). `Standard` or `Premium`."
  nullable    = false

  validation {
    condition     = !var.tunneling_enabled || contains(["Standard", "Premium"], var.sku)
    error_message = "`tunneling_enabled` needs `Standard` or `Premium`."
  }
}

variable "virtual_network_id" {
  type        = string
  default     = null
  description = "(Optional) Resource ID of the virtual network a `Developer` bastion host serves: required for `Developer`, not taken by the other tiers (which take `ip_configuration`). Changing it replaces the bastion host."

  validation {
    condition     = (var.virtual_network_id != null) == (var.sku == "Developer")
    error_message = "`virtual_network_id` is required for `Developer` and not taken by the other tiers."
  }
  validation {
    condition     = var.virtual_network_id == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.virtual_network_id))
    error_message = "`virtual_network_id` must be a virtual network resource ID."
  }
}

variable "zones" {
  type        = list(string)
  default     = null
  description = "(Optional) Availability zones of the bastion host: several for a zone-redundant one, for example `[\"1\", \"2\", \"3\"]`, or one for a zonal one. In preview, in some regions only (Microsoft Learn, \"Reliability in Azure Bastion\"). Null leaves them out. Azure can't change them on an existing bastion host, so changing them replaces it."

  validation {
    condition     = var.zones == null ? true : length(var.zones) > 0 && alltrue([for zone in var.zones : contains(["1", "2", "3"], zone)])
    error_message = "`zones` must be null or a non-empty list of `1`, `2` and `3`."
  }
}
