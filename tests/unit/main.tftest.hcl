mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/bastionHosts/bas-test"
      output = {
        properties = {
          dnsName   = "bst-00000000-0000-0000-0000-000000000000.bastion.azure.com"
          ipAddress = "203.0.113.10"
        }
      }
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          }
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

variables {
  location  = "swedencentral"
  name      = "bas-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  ip_configuration = {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureBastionSubnet"
    public_ip = { name = "pip-bas-test" }
  }
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/bastionHosts@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The bastion host should use the default resource type, name, parent_id and location."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body) == jsonencode({
      properties = {
        disableCopyPaste       = false
        enableFileCopy         = false
        enableIpConnect        = false
        enableKerberos         = false
        enableSessionRecording = false
        enableShareableLink    = false
        enableTunneling        = false
        ipConfigurations = [{
          name = "ipconfig"
          properties = {
            subnet          = { id = var.ip_configuration.subnet_id }
            publicIPAddress = { id = module.public_ip[0].resource_id }
          }
        }]
        enablePrivateOnlyBastion = false
        scaleUnits               = 2
      }
      sku = { name = "Standard" }
    })
    error_message = "A Standard bastion host in AzureBastionSubnet with a created public IP address, every feature sent as off and no zones."
  }
  assert {
    condition = jsonencode(azapi_resource.this.replace_triggers_external_values) == jsonencode({
      developer        = false
      ip_configuration = { name = "ipconfig", public_ip = jsonencode({ name = "pip-bas-test", public_ip_prefix_id = null }) }
      private_only     = false
      virtual_network  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg-test/providers/microsoft.network/virtualnetworks/vnet-hub"
      zones            = null
    })
    error_message = "The replacement triggers should be the tier kind, IP configuration, private-only, virtual network and zones."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.retry.interval_seconds == 30 && azapi_resource.this.retry.max_interval_seconds == 300 && azapi_resource.this.timeouts == null
    error_message = "retry should default to AnotherOperationInProgress and timeouts to null."
  }
  assert {
    condition     = length(coalesce(azapi_resource.this.tags, {})) == 0 # computed: the mock returns {}
    error_message = "tags should be unset by default."
  }
  assert {
    condition     = length(module.public_ip) == 1 && module.interfaces.lock_resource_id == null && length(module.interfaces.role_assignment_resource_ids) + length(module.interfaces.diagnostic_setting_resource_ids) == 0
    error_message = "One public IP address and no lock, role assignment or diagnostic setting should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && output.dns_name == "bst-00000000-0000-0000-0000-000000000000.bastion.azure.com"
    error_message = "resource_id, name and dns_name should come from the bastion host."
  }
  assert {
    condition     = output.public_ip_address_id == module.public_ip[0].resource_id && output.public_ip_address == "203.0.113.10"
    error_message = "The public IP address outputs should come from the created address."
  }
}

run "developer" {
  command = apply

  variables {
    sku                = "Developer"
    ip_configuration   = null
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-dev"
    ip_rules           = ["203.0.113.0/24", "198.51.100.7"]
  }

  assert {
    condition = jsonencode(azapi_resource.this.body) == jsonencode({
      properties = {
        virtualNetwork = { id = var.virtual_network_id }
        networkAcls    = { ipRules = [{ addressPrefix = "203.0.113.0/24" }, { addressPrefix = "198.51.100.7" }] }
      }
      sku = { name = "Developer" }
    })
    error_message = "A Developer bastion host should send only its virtual network and IP rules: Azure rejects any feature property on it."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.developer && azapi_resource.this.replace_triggers_external_values.ip_configuration == null && azapi_resource.this.replace_triggers_external_values.virtual_network == lower(var.virtual_network_id)
    error_message = "A Developer bastion host should be replaced when it moves to another virtual network or tier kind."
  }
  assert {
    condition     = length(module.public_ip) == 0 && output.public_ip_address_id == null && output.public_ip_address == null
    error_message = "A Developer bastion host has no public IP address."
  }
}

run "private_only" {
  command = apply

  variables {
    sku                       = "Premium"
    private_only_enabled      = true
    session_recording_enabled = true
    ip_configuration = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureBastionSubnet"
    }
  }

  assert {
    condition     = azapi_resource.this.body.properties.enablePrivateOnlyBastion && azapi_resource.this.body.properties.enableSessionRecording && azapi_resource.this.body.properties.ipConfigurations[0].properties.publicIPAddress == null && azapi_resource.this.body.sku.name == "Premium"
    error_message = "A private-only Premium bastion host should send a null public IP address, private-only and session recording."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.private_only && azapi_resource.this.replace_triggers_external_values.ip_configuration.public_ip == null
    error_message = "Private-only should be a replacement trigger."
  }
  assert {
    condition     = length(module.public_ip) == 0 && output.public_ip_address_id == null && output.public_ip_address == null
    error_message = "A private-only bastion host has no public IP address."
  }
}

run "existing_public_ip" {
  command = apply

  variables {
    sku = "Basic"
    ip_configuration = {
      name                  = "IpConf"
      subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureBastionSubnet"
      public_ip_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/PIP-Existing"
    }
  }

  assert {
    condition     = jsonencode(azapi_resource.this.body.properties.ipConfigurations) == jsonencode([{ name = "IpConf", properties = { subnet = { id = var.ip_configuration.subnet_id }, publicIPAddress = { id = var.ip_configuration.public_ip_resource_id } } }])
    error_message = "An existing public IP address should be used as given, in the named IP configuration."
  }
  assert {
    condition     = azapi_resource.this.body.sku.name == "Basic" && azapi_resource.this.body.properties.scaleUnits == 2
    error_message = "A Basic bastion host should send its two scale units."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.replace_triggers_external_values.ip_configuration) == jsonencode({ name = "IpConf", public_ip = lower(var.ip_configuration.public_ip_resource_id) })
    error_message = "An existing public IP address should be compared case-insensitively."
  }
  assert {
    condition     = length(module.public_ip) == 0 && output.public_ip_address_id == var.ip_configuration.public_ip_resource_id && output.public_ip_address == null
    error_message = "No public IP address should be created; the given ID should be output."
  }
}

run "standard_features_and_zones" {
  command = apply

  variables {
    copy_paste_enabled     = false
    file_copy_enabled      = true
    ip_connect_enabled     = true
    kerberos_enabled       = true
    shareable_link_enabled = true
    tunneling_enabled      = true
    scale_units            = 5
    zones                  = ["3", "1", "2", "1"]
    ip_configuration = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureBastionSubnet"
      public_ip = {
        name                = "pip-bas-test"
        public_ip_prefix_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPPrefixes/ippre-test"
      }
    }
  }

  assert {
    condition = alltrue([
      azapi_resource.this.body.properties.disableCopyPaste,
      azapi_resource.this.body.properties.enableFileCopy,
      azapi_resource.this.body.properties.enableIpConnect,
      azapi_resource.this.body.properties.enableKerberos,
      azapi_resource.this.body.properties.enableShareableLink,
      azapi_resource.this.body.properties.enableTunneling,
      !azapi_resource.this.body.properties.enableSessionRecording,
      azapi_resource.this.body.properties.scaleUnits == 5,
    ])
    error_message = "The Standard features and scale units should reach the body."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.body.zones) == jsonencode(["1", "2", "3"]) && jsonencode(azapi_resource.this.replace_triggers_external_values.zones) == jsonencode(["1", "2", "3"])
    error_message = "Zones should be sorted and deduplicated, in the body and the replacement triggers."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.ip_configuration.public_ip == jsonencode(var.ip_configuration.public_ip)
    error_message = "The created public IP address, prefix included, should be a replacement trigger."
  }
}

run "interfaces" {
  command = apply

  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = "11111111-1111-1111-1111-111111111111" }
    }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
        logs                  = [{ category = "BastionAuditLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }

  assert {
    condition     = module.interfaces.lock_resource_id != null && length(module.interfaces.role_assignment_resource_ids) == 1 && length(module.interfaces.diagnostic_setting_resource_ids) == 1
    error_message = "The lock, the role assignment and the diagnostic setting should be created."
  }
}

run "azapi_settings" {
  command = apply

  variables {
    resource_types = { network_bastion_hosts = "Microsoft.Network/bastionHosts@2024-05-01" }
    retry          = { error_message_regex = ["Conflict"], interval_seconds = 5 }
    timeouts       = { create = "45m", delete = "30m" }
    tags           = { environment = "test" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/bastionHosts@2024-05-01"
    error_message = "resource_types should override the bastion host's type."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["Conflict"]) && azapi_resource.this.retry.interval_seconds == 5 && azapi_resource.this.retry.max_interval_seconds == 300
    error_message = "retry should keep the defaults of fields not overridden."
  }
  assert {
    condition     = azapi_resource.this.timeouts.create == "45m" && azapi_resource.this.timeouts.delete == "30m"
    error_message = "timeouts should reach the bastion host."
  }
  assert {
    condition     = azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "tags should reach the bastion host."
  }
}

run "invalid_name" {
  command = plan

  variables {
    name = "bas-test-"
  }

  expect_failures = [var.name]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "invalid_sku" {
  command = plan

  variables {
    sku = "Free"
  }

  expect_failures = [var.sku]
}

run "developer_with_ip_configuration" {
  command = plan

  variables {
    sku                = "Developer"
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-dev"
  }

  expect_failures = [var.ip_configuration]
}

run "developer_without_virtual_network" {
  command = plan

  variables {
    sku              = "Developer"
    ip_configuration = null
  }

  expect_failures = [var.virtual_network_id]
}

run "dedicated_with_virtual_network_id" {
  command = plan

  variables {
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub"
  }

  expect_failures = [var.virtual_network_id]
}

run "dedicated_without_ip_configuration" {
  command = plan

  variables {
    ip_configuration = null
  }

  expect_failures = [var.ip_configuration]
}

run "invalid_virtual_network_id" {
  command = plan

  variables {
    sku                = "Developer"
    ip_configuration   = null
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-dev/subnets/default"
  }

  expect_failures = [var.virtual_network_id]
}

run "wrong_subnet" {
  command = plan

  variables {
    ip_configuration = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/default"
      public_ip = { name = "pip-bas-test" }
    }
  }

  expect_failures = [var.ip_configuration]
}

run "no_public_ip" {
  command = plan

  variables {
    ip_configuration = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureBastionSubnet"
    }
  }

  expect_failures = [var.ip_configuration]
}

run "both_public_ips" {
  command = plan

  variables {
    ip_configuration = {
      subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureBastionSubnet"
      public_ip             = { name = "pip-bas-test" }
      public_ip_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-existing"
    }
  }

  expect_failures = [var.ip_configuration]
}

run "private_only_with_public_ip" {
  command = plan

  variables {
    sku                  = "Premium"
    private_only_enabled = true
  }

  expect_failures = [var.ip_configuration]
}

run "private_only_on_standard" {
  command = plan

  variables {
    private_only_enabled = true
    ip_configuration = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureBastionSubnet"
    }
  }

  expect_failures = [var.private_only_enabled]
}

run "invalid_public_ip_resource_id" {
  command = plan

  variables {
    ip_configuration = {
      subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/AzureBastionSubnet"
      public_ip_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPPrefixes/ippre-test"
    }
  }

  expect_failures = [var.ip_configuration]
}

run "standard_features_on_basic" {
  command = plan

  variables {
    sku                    = "Basic"
    copy_paste_enabled     = false
    file_copy_enabled      = true
    ip_connect_enabled     = true
    shareable_link_enabled = true
    tunneling_enabled      = true
    scale_units            = 3
  }

  expect_failures = [
    var.copy_paste_enabled,
    var.file_copy_enabled,
    var.ip_connect_enabled,
    var.shareable_link_enabled,
    var.tunneling_enabled,
    var.scale_units,
  ]
}

run "session_recording_on_standard" {
  command = plan

  variables {
    session_recording_enabled = true
  }

  expect_failures = [var.session_recording_enabled]
}

run "too_many_scale_units" {
  command = plan

  variables {
    scale_units = 51
  }

  expect_failures = [var.scale_units]
}

run "ip_rules_on_standard" {
  command = plan

  variables {
    ip_rules = ["203.0.113.0/24"]
  }

  expect_failures = [var.ip_rules]
}

run "invalid_ip_rule" {
  command = plan

  variables {
    sku                = "Developer"
    ip_configuration   = null
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-dev"
    ip_rules           = ["2001:db8::/32"]
  }

  expect_failures = [var.ip_rules]
}

run "kerberos_on_developer" {
  command = plan

  variables {
    sku                = "Developer"
    ip_configuration   = null
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-dev"
    kerberos_enabled   = true
  }

  expect_failures = [var.kerberos_enabled]
}

run "invalid_zones" {
  command = plan

  variables {
    zones = ["4"]
  }

  expect_failures = [var.zones]
}

run "invalid_lock_kind" {
  command = plan

  variables {
    lock = { kind = "DoNotDelete" }
  }

  expect_failures = [var.lock]
}
