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
  count = length(var.amd_micro_instances) > 0 ? 1 : 0

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
