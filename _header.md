# az-tf-mlz-bastion

A Fortytwo managed landing zone (MLZ) module for Azure Bastion, in AzAPI: the bastion host
(`Microsoft.Network/bastionHosts`) and its public IP address.

- **Every tier** (`sku`, default `Standard`). `Developer` is free and shared, for one virtual network
  (`virtual_network_id`, optionally `ip_rules`), for development and test. `Basic`, `Standard` and
  `Premium` are dedicated hosts in the caller's `AzureBastionSubnet` (`ip_configuration`); they upgrade
  into each other in place, and Azure supports no downgrade.
- **A public IP address** created through
  [`az-tf-mlz-public-ip`](https://github.com/fortytwoservices/az-tf-mlz-public-ip)
  (`ip_configuration.public_ip`) or given by ID; none for `Developer` and for a private-only `Premium`
  host (`private_only_enabled`).
- **One variable per feature**, checked against the tier: copy and paste, file copy, IP-based
  connection, Kerberos, shareable links, native client (`tunneling_enabled`), session recording and
  scale units. Every feature is sent, off when unset, so turning one off reaches Azure. Session
  recording's storage container is set in the portal, not here.
- **Zones** are left out unless set, and a host in zones gets a zone-redundant public IP address, as
  Azure requires. Changing the zones, private-only, `Developer` to or from a dedicated tier, the virtual
  network or the IP configuration replaces the bastion host.
- Lock, role assignments and diagnostic settings (`BastionAuditLogs`, `AllMetrics`), as in Azure Verified
  Modules, through [`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces).

```hcl
module "bastion" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-bastion.git?ref=vX.Y.Z"

  name      = "bas-hub-sdc"
  parent_id = "/subscriptions/<subscription>/resourceGroups/<resource group>"
  location  = "swedencentral"
  ip_configuration = {
    subnet_id = "<AzureBastionSubnet ID>"
    public_ip = { name = "pip-bas-hub-sdc" }
  }
  tunneling_enabled = true
}
```

The examples deploy a Standard bastion host with a public IP address and diagnostics (`default`) and a
Developer one (`developer`).
