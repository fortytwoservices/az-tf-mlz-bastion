# Real Azure, no mocks. A private-only Premium bastion host, without a public IP address, created with
# session recording, then with session recording off. Proves the private-only body is accepted and
# that turning session recording off reaches Azure.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name                      = "bas-mlz-bas-${run.setup.suffix}"
    parent_id                 = run.setup.resource_group_id
    location                  = run.setup.location
    sku                       = "Premium"
    private_only_enabled      = true
    session_recording_enabled = true
    ip_configuration          = { subnet_id = run.setup.bastion_subnet_id }
  }

  assert {
    condition     = output.public_ip_address_id == null
    error_message = "A private-only bastion host has no public IP address."
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
    condition     = output.sku == "Premium" && output.properties.enablePrivateOnlyBastion && output.properties.enableSessionRecording && try(output.properties.ipConfigurations[0].properties.publicIPAddress.id, null) == null
    error_message = "Azure should report a private-only Premium bastion host with session recording and no public IP address."
  }
}

run "session_recording_off" {
  variables {
    name                 = "bas-mlz-bas-${run.setup.suffix}"
    parent_id            = run.setup.resource_group_id
    location             = run.setup.location
    sku                  = "Premium"
    private_only_enabled = true
    ip_configuration     = { subnet_id = run.setup.bastion_subnet_id }
  }
}

run "session_recording_off_in_azure" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    bastion_id = run.session_recording_off.resource_id
  }

  assert {
    condition     = !output.properties.enableSessionRecording && output.properties.enablePrivateOnlyBastion
    error_message = "Azure should report session recording off once it is no longer set."
  }
}
