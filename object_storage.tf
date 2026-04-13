# CHARGE WARNING: Object Storage is free up to 20 GB and 50,000 API requests
# per month. Exceeding either limit will incur standard storage charges. The
# bucket itself is free; charges depend on how much data you store in it.
# Monitor usage in the OCI console.
resource "oci_objectstorage_bucket" "main" {
  count = var.features.object_storage ? 1 : 0

  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  freeform_tags  = local.common_freeform_tags
  name           = local.bucket_name
  namespace      = data.oci_objectstorage_namespace.this.namespace
  storage_tier   = "Standard"
}
