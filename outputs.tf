output "dns_name" {
  description = "The bastion host's DNS name, as Azure reports it; null if Azure reports none."
  value       = try(azapi_resource.this.output.properties.dnsName, null)
}

output "name" {
  description = "Name of the bastion host."
  value       = azapi_resource.this.name
}

output "public_ip_address" {
  description = "IP address of the public IP address the module creates; null when it creates none."
  value       = one(module.public_ip[*].ip_address)
}

output "public_ip_address_id" {
  description = "Resource ID of the bastion host's public IP address, created or given; null for `Developer` and private-only."
  value       = local.public_ip_id
}

output "resource_id" {
  description = "Resource ID of the bastion host."
  value       = azapi_resource.this.id
}
