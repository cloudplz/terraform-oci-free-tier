data "oci_core_images" "a1" {
  compartment_id           = var.compartment_id
  operating_system         = local.image_operating_system
  operating_system_version = var.operating_system_version
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

data "oci_core_images" "micro" {
  count = length(local.effective_amd_micro_instances) > 0 ? 1 : 0

  compartment_id           = var.compartment_id
  operating_system         = local.image_operating_system
  operating_system_version = var.operating_system_version
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

data "oci_identity_availability_domains" "available" {
  compartment_id = var.compartment_id
}

data "oci_identity_region_subscriptions" "home" {
  count      = var.tenancy_id != null ? 1 : 0
  tenancy_id = var.tenancy_id
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_id
}

data "oci_core_volume_backup_policies" "oracle_defined" {
  count = var.features.boot_volume_backup ? 1 : 0
}

check "total_storage_budget" {
  assert {
    condition     = local.total_storage_gb <= 200
    error_message = "Total storage (boot + block volumes) is ${local.total_storage_gb} GB, which exceeds the 200 GB Always Free limit."
  }
}

check "block_volume_mount_uniqueness" {
  assert {
    condition = length([
      for target in distinct([for v in values(local.effective_block_volumes) : v.attach_to if v.mount_point != null]) :
      target
      if length([for v in values(local.effective_block_volumes) : v if v.attach_to == target && v.mount_point != null]) > 1
    ]) == 0
    error_message = "Each compute instance may have at most one block volume with mount_point set."
  }
}

check "block_volume_attachment_targets" {
  assert {
    condition = alltrue([
      for key, vol in local.effective_block_volumes :
      contains(keys(local.effective_compute_instances), vol.attach_to)
    ])
    error_message = "One or more block volumes reference a compute instance key that does not exist."
  }
}

check "load_balancer_backend_keys" {
  assert {
    condition = alltrue([
      for key in coalesce(var.load_balancer_backend_instance_keys, toset([])) :
      contains(keys(local.effective_compute_instances), key)
    ])
    error_message = "All load_balancer_backend_instance_keys must match keys in the effective compute_instances (profile or explicit)."
  }
}

check "home_region" {
  assert {
    condition = (
      var.tenancy_id == null ||
      local.current_region_key == null ||
      local.home_region_key == null ||
      local.current_region_key == local.home_region_key
    )
    error_message = "The OCI provider appears to be configured for region '${coalesce(local.current_region_key, "unknown")}' but the tenancy home region is '${coalesce(local.home_region_key, "unknown")}'. Always Free resources are only free in the home region and will incur charges elsewhere."
  }
}
