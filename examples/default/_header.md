# Default example

A resource group, a virtual network with `AzureBastionSubnet` and a Log Analytics workspace, then a
Standard bastion host with a public IP address the module creates, native client support and IP-based
connection turned on, and its logs and metrics sent to the workspace. In Sweden Central.

Run it with `scripts/e2e.sh examples/default`: apply, a second plan that must be empty, destroy. The
bastion host is billed by the hour from the moment it exists, so do not leave it running.
