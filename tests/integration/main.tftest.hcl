# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> terraform test -test-directory=tests/integration
# A dedicated bastion host in zones, created as Basic with a public IP address, then upgraded to Standard
# with every Standard feature on, then with every feature off again, all under a lock. Proves the
# upgrade happens in place and that turning a feature off reaches Azure. Each write takes about ten
# minutes.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name      = "bas-mlz-bas-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku       = "Basic"
    zones     = ["1", "2", "3"]
    ip_configuration = {
      subnet_id = run.setup.bastion_subnet_id
      public_ip = { name = "pip-mlz-bas-${run.setup.suffix}" }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category = "BastionAuditLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }

  assert {
    condition     = output.public_ip_address != null && output.public_ip_address_id != null && output.dns_name != null
    error_message = "The public IP address and the DNS name should be read back from Azure."
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
    condition     = output.sku == "Basic" && output.properties.scaleUnits == 2 && jsonencode(output.zones) == jsonencode(["1", "2", "3"])
    error_message = "Azure should report a Basic bastion host with two scale units in zones 1, 2 and 3."
  }
}

run "upgrade_to_standard" {
  # In place under the lock: Basic, Standard and Premium share their infrastructure.
  variables {
    name      = "bas-mlz-bas-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku       = "Standard"
    zones     = ["1", "2", "3"]
    ip_configuration = {
      subnet_id = run.setup.bastion_subnet_id
      public_ip = { name = "pip-mlz-bas-${run.setup.suffix}" }
    }
    copy_paste_enabled     = false
    file_copy_enabled      = true
    ip_connect_enabled     = true
    kerberos_enabled       = true
    shareable_link_enabled = true
    tunneling_enabled      = true
    scale_units            = 3
    lock                   = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category = "BastionAuditLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }

  assert {
    condition     = output.public_ip_address == run.create.public_ip_address && module.interfaces.lock_resource_id != null
    error_message = "The upgrade should keep the public IP address and the lock."
  }
}

run "upgraded_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    bastion_id = run.upgrade_to_standard.resource_id
  }

  assert {
    condition = alltrue([
      output.sku == "Standard",
      output.properties.scaleUnits == 3,
      output.properties.disableCopyPaste,
      output.properties.enableFileCopy,
      output.properties.enableIpConnect,
      output.properties.enableKerberos,
      output.properties.enableShareableLink,
      output.properties.enableTunneling,
    ])
    error_message = "Azure should report a Standard bastion host with three scale units and every Standard feature on."
  }
}

run "features_off" {
  variables {
    name      = "bas-mlz-bas-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    sku       = "Standard"
    zones     = ["1", "2", "3"]
    ip_configuration = {
      subnet_id = run.setup.bastion_subnet_id
      public_ip = { name = "pip-mlz-bas-${run.setup.suffix}" }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category = "BastionAuditLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }
}

run "features_off_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    bastion_id = run.features_off.resource_id
  }

  assert {
    condition = alltrue([
      output.sku == "Standard",
      output.properties.scaleUnits == 2,
      !output.properties.disableCopyPaste,
      !output.properties.enableFileCopy,
      !output.properties.enableIpConnect,
      !output.properties.enableKerberos,
      !output.properties.enableShareableLink,
      !output.properties.enableTunneling,
    ])
    error_message = "Azure should report every feature off and two scale units once they are no longer set."
  }
}
