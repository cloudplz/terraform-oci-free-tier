output "compute_instances" {
  description = "Map of compute instance details (IDs, IPs, ADs)."
  value       = module.free_tier.compute_instances
}

output "vcn_id" {
  description = "VCN OCID."
  value       = module.free_tier.vcn_id
}

output "mysql_db_system_ip_address" {
  description = "MySQL DB system private IP."
  value       = module.free_tier.mysql_db_system_ip_address
}

output "mysql_admin_password_secret_id" {
  description = "Vault secret OCID for the MySQL admin password."
  value       = module.free_tier.mysql_admin_password_secret_id
}

output "load_balancer_ip_addresses" {
  description = "Load balancer public IPs."
  value       = module.free_tier.load_balancer_ip_addresses
}
