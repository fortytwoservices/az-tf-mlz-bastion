resource "azapi_resource" "this" {
  type      = var.resource_types.network_bastion_hosts
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  body = merge(
    {
      sku = { name = var.sku }
      properties = merge(
        # merge() skips null, which unlike {} unifies with either object type. Developer: a shared host
        # for one virtual network. Azure rejects any feature property on it, even false
        # (FeatureNotSupportedForDeveloperBastionSku, sandbox 2026-10-28).
        local.developer ? {
          virtualNetwork = { id = var.virtual_network_id }
          networkAcls    = { ipRules = [for rule in var.ip_rules : { addressPrefix = rule }] }
        } : null,
        # Basic, Standard and Premium: a dedicated host in AzureBastionSubnet; private-only has no public
        # IP address. Every feature is sent, false when off: azapi compares only the keys in the body,
        # so a feature left out when turned off would stay on in Azure.
        local.developer ? null : {
          ipConfigurations = [{
            name = var.ip_configuration.name
            properties = {
              subnet          = { id = var.ip_configuration.subnet_id }
              publicIPAddress = local.public_ip_id == null ? null : { id = local.public_ip_id }
            }
          }]
          disableCopyPaste         = !var.copy_paste_enabled
          enableFileCopy           = var.file_copy_enabled
          enableIpConnect          = var.ip_connect_enabled
          enableKerberos           = var.kerberos_enabled
          enablePrivateOnlyBastion = var.private_only_enabled
          enableSessionRecording   = var.session_recording_enabled
          enableShareableLink      = var.shareable_link_enabled
          enableTunneling          = var.tunneling_enabled
          scaleUnits               = var.scale_units
        },
      )
    },
    # Left out when null, so Azure's choice is not compared; sorted, so their order changes nothing.
    local.zones == null ? null : { zones = local.zones },
  )
  ignore_body_changes = length(var.ignore_body_changes.network_bastion_hosts) > 0 ? var.ignore_body_changes.network_bastion_hosts : null
  # What Azure changes only by creating the bastion host again: its zones (Microsoft Learn, "Reliability
  # in Azure Bastion"), private-only ("Deploy Bastion as private-only"), Developer to or from a dedicated
  # tier ("View or upgrade an Azure Bastion SKU": the IP configuration can't be added), and the virtual
  # network it serves. A changed IP configuration replaces it too: whether Azure updates one in place is
  # unverified, and a public IP address can be replaced only once nothing uses it. Compared as inputs, so
  # going back to null also replaces it.
  replace_triggers_external_values = {
    developer = local.developer
    ip_configuration = var.ip_configuration == null ? null : {
      name      = var.ip_configuration.name
      public_ip = var.ip_configuration.public_ip != null ? jsonencode(var.ip_configuration.public_ip) : var.ip_configuration.public_ip_resource_id == null ? null : lower(var.ip_configuration.public_ip_resource_id)
    }
    private_only    = var.private_only_enabled
    virtual_network = lower(local.virtual_network_id)
    zones           = local.zones
  }
  response_export_values = ["properties.dnsName"]
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
