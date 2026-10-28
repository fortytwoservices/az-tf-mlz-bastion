output "dns_name" {
  description = "The bastion host's DNS name."
  value       = module.bastion.dns_name
}

output "public_ip_address" {
  description = "The bastion host's public IP address."
  value       = module.bastion.public_ip_address
}

output "resource_id" {
  description = "Resource ID of the bastion host."
  value       = module.bastion.resource_id
}
