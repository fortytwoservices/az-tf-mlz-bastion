# Real Azure, no mocks. A Developer bastion host (free, shared) for a virtual network without
# AzureBastionSubnet: created with an IP rule, then changed to none. Proves the Developer body is
# accepted (Azure rejects any feature property on Developer, even false) and that removing the IP rules
# reaches Azure.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }

  variables {
    bastion_subnet = false
  }
}

run "create" {
  variables {
    name               = "bas-mlz-bas-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    sku                = "Developer"
    virtual_network_id = run.setup.virtual_network_id
    ip_rules           = ["203.0.113.0/24"]
  }

  assert {
    condition     = output.public_ip_address_id == null
    error_message = "A Developer bastion host has no public IP address."
  }
}

run "created_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    bastion_id = run.create.resource_id
  }

  assert {
    condition     = output.sku == "Developer" && lower(output.properties.virtualNetwork.id) == lower(run.setup.virtual_network_id) && jsonencode(output.properties.networkAcls.ipRules) == jsonencode([{ addressPrefix = "203.0.113.0/24" }])
    error_message = "Azure should report a Developer bastion host for the virtual network, with the IP rule."
  }
}

run "update" {
  variables {
    name               = "bas-mlz-bas-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    sku                = "Developer"
    virtual_network_id = run.setup.virtual_network_id
  }
}

run "updated_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    bastion_id = run.update.resource_id
  }

  assert {
    condition     = length(try(output.properties.networkAcls.ipRules, [])) == 0
    error_message = "Azure should report no IP rule once none is set."
  }
}
