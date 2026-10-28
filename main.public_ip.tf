module "public_ip" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git?ref=v0.1.2"
  count  = local.create_public_ip ? 1 : 0

  name      = var.ip_configuration.public_ip.name
  parent_id = var.parent_id
  location  = var.location
  # A bastion host in zones needs a zone-redundant public IP address (Microsoft Learn, "Reliability in
  # Azure Bastion"), whether the host itself is zone-redundant or zonal.
  zones               = local.zones == null ? null : ["1", "2", "3"]
  public_ip_prefix_id = var.ip_configuration.public_ip.public_ip_prefix_id
  tags                = var.tags
  resource_types      = var.resource_types.network_public_ip_addresses
  ignore_body_changes = var.ignore_body_changes.network_public_ip_addresses
  retry               = var.retry
  timeouts            = var.timeouts
}
