locals {
  developer = var.sku == "Developer"
  # Only the presence of the object decides whether the address is created, so a name unknown until
  # apply cannot make the count unknown.
  create_public_ip = var.ip_configuration == null ? false : var.ip_configuration.public_ip != null
  # The public IP address, created or existing; null for Developer and private-only.
  public_ip_id = local.create_public_ip ? one(module.public_ip[*].resource_id) : var.ip_configuration == null ? null : var.ip_configuration.public_ip_resource_id
  # The virtual network the bastion host serves: given for Developer, the subnet's parent otherwise.
  virtual_network_id = var.ip_configuration == null ? var.virtual_network_id : provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", var.ip_configuration.subnet_id).parent_id
  zones              = var.zones == null ? null : sort(distinct(var.zones))
}
