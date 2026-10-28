# Developer example

A resource group and a virtual network, then a Developer bastion host for it: free, on shared
infrastructure, without `AzureBastionSubnet` or a public IP address, one connection at a time. For
development and test only. In Sweden Central, one of the regions that offer it.

Run it with `scripts/e2e.sh examples/developer`: apply, a second plan that must be empty, destroy.
