# CHARGE WARNING -- Defaults to OFF (features.boot_volume_backup = false).
# The bronze policy creates monthly backups with 12-month retention. A fleet of
# 3 VMs exceeds the 5-backup Always Free limit within 2 months. Enable only if
# you actively monitor and prune backups, or accept potential charges.
resource "oci_core_volume_backup_policy_assignment" "a1_boot" {
  for_each = var.features.boot_volume_backup ? local.effective_compute_instances : {}

  asset_id  = oci_core_instance.vm[each.key].boot_volume_id
  policy_id = local.bronze_backup_policy_id
}

resource "oci_core_volume_backup_policy_assignment" "micro_boot" {
  for_each = var.features.boot_volume_backup ? local.effective_amd_micro_instances : {}

  asset_id  = oci_core_instance.micro[each.key].boot_volume_id
  policy_id = local.bronze_backup_policy_id
}
