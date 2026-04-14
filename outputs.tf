output "amd_micro_instances" {
  description = "Map of AMD Micro instance details keyed by instance name, or an empty map when none are configured."
  value = {
    for key, instance in oci_core_instance.micro : key => {
      availability_domain = instance.availability_domain
      boot_volume_id      = instance.boot_volume_id
      id                  = instance.id
      private_ip          = instance.private_ip
      public_ip           = try(instance.public_ip, null)
      subnet_role         = try(local.effective_amd_micro_instances[key].subnet_role, "public")
    }
  }
}

output "budget_id" {
  description = "OCID of the safety-net budget, or null when disabled or tenancy_id is not set."
  value       = try(oci_budget_budget.free_tier[0].id, null)
}

output "availability_domain" {
  description = "Default availability domain used for compute instances without an explicit per-instance override."
  value       = local.availability_domain
}

output "compute_instances" {
  description = "Map of compute instance details keyed by instance name."
  value = {
    for key, instance in oci_core_instance.vm : key => {
      availability_domain = instance.availability_domain
      boot_volume_id      = instance.boot_volume_id
      id                  = instance.id
      ocpus               = instance.shape_config[0].ocpus
      private_ip          = instance.private_ip
      public_ip           = try(instance.public_ip, null)
      subnet_role         = try(local.effective_compute_instances[key].subnet_role, "public")
    }
  }
}

output "load_balancer_id" {
  description = "OCID of the optional load balancer, or null when disabled."
  value       = try(oci_load_balancer_load_balancer.main[0].id, null)
}

output "load_balancer_ip_addresses" {
  description = "IP addresses assigned to the optional load balancer, or an empty list when disabled."
  value       = try([for detail in oci_load_balancer_load_balancer.main[0].ip_address_details : detail.ip_address], [])
}

output "mysql_db_system_id" {
  description = "OCID of the optional Always Free MySQL DB system, or null when disabled."
  value       = try(oci_mysql_mysql_db_system.main[0].id, null)
}

output "mysql_db_system_ip_address" {
  description = "Private IP address of the MySQL DB system endpoint, or null when disabled."
  value       = try(oci_mysql_mysql_db_system.main[0].ip_address, null)
}

output "mysql_admin_password" {
  description = "MySQL admin password when features.mysql is enabled."
  value       = local.mysql_admin_password
  sensitive   = true
}

output "postgresql_db_system_id" {
  description = "OCID of the optional PostgreSQL DB system, or null when disabled."
  value       = try(oci_psql_db_system.main[0].id, null)
}

output "postgresql_db_system_ip_address" {
  description = "Private IP address of the PostgreSQL DB system primary endpoint, or null when disabled."
  value       = try(oci_psql_db_system.main[0].network_details[0].primary_db_endpoint_private_ip, null)
}

output "postgresql_admin_password" {
  description = "PostgreSQL admin password when features.postgresql is enabled."
  value       = local.postgresql_admin_password
  sensitive   = true
}

output "network_load_balancer_id" {
  description = "OCID of the optional network load balancer, or null when disabled."
  value       = try(oci_network_load_balancer_network_load_balancer.main[0].id, null)
}

output "network_load_balancer_ip_addresses" {
  description = "IP addresses assigned to the optional network load balancer, or an empty list when disabled."
  value       = try(oci_network_load_balancer_network_load_balancer.main[0].ip_addresses, [])
}

output "object_storage_bucket_name" {
  description = "Name of the optional Object Storage bucket, or null when disabled."
  value       = try(oci_objectstorage_bucket.main[0].name, null)
}

output "object_storage_namespace" {
  description = "Object Storage namespace for the tenancy."
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "private_subnet_id" {
  description = "OCID of the private subnet."
  value       = oci_core_subnet.private.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet."
  value       = oci_core_subnet.public.id
}

output "vcn_cidr" {
  description = "CIDR block of the VCN."
  value       = var.vcn_cidr
}

output "vault_id" {
  description = "OCID of the OCI Vault, or null when vault is not created."
  value       = try(oci_kms_vault.main[0].id, null)
}

output "vault_crypto_endpoint" {
  description = "Vault cryptographic operations endpoint, or null when vault is not created."
  value       = try(oci_kms_vault.main[0].crypto_endpoint, null)
}

output "vault_management_endpoint" {
  description = "Vault management operations endpoint, or null when vault is not created."
  value       = try(oci_kms_vault.main[0].management_endpoint, null)
}

output "mysql_admin_password_secret_id" {
  description = "OCID of the Vault secret containing the MySQL admin password, or null when vault or MySQL is disabled."
  value       = try(oci_vault_secret.mysql_admin_password[0].id, null)
}

output "postgresql_admin_password_secret_id" {
  description = "OCID of the Vault secret containing the PostgreSQL admin password, or null when vault or PostgreSQL is disabled."
  value       = try(oci_vault_secret.postgresql_admin_password[0].id, null)
}

output "vcn_id" {
  description = "OCID of the VCN."
  value       = oci_core_vcn.main.id
}

output "block_volumes" {
  description = "Map of block volume details keyed by volume name, or an empty map when none are configured."
  value = {
    for key, vol in oci_core_volume.data : key => {
      id            = vol.id
      attachment_id = oci_core_volume_attachment.data[key].id
      device        = try(oci_core_volume_attachment.data[key].device, null)
      mount_point   = try(local.effective_block_volumes[key].mount_point, null)
    }
  }
}
