# -----------------------------------------------------------------------------
# OCI Vault / Key Management (Always Free)
# -----------------------------------------------------------------------------

# Always Free: software-protected vaults and keys are free. Up to 20 master
# encryption key versions and 150 Vault secrets per tenancy. This module uses
# SOFTWARE protection mode only.

resource "oci_kms_vault" "main" {
  count = local.needs_vault ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "${var.name}-vault"
  vault_type     = "DEFAULT"
  defined_tags   = local.common_defined_tags
  freeform_tags  = local.common_freeform_tags
}

resource "oci_kms_key" "secrets" {
  count = local.needs_vault ? 1 : 0

  compartment_id      = var.compartment_id
  display_name        = "${var.name}-secrets-key"
  management_endpoint = oci_kms_vault.main[0].management_endpoint
  protection_mode     = "SOFTWARE"
  defined_tags        = local.common_defined_tags
  freeform_tags       = local.common_freeform_tags

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

# --- MySQL admin password secret ---

resource "oci_vault_secret" "mysql_admin_password" {
  count = local.needs_vault && var.features.mysql ? 1 : 0

  compartment_id = var.compartment_id
  key_id         = oci_kms_key.secrets[0].id
  secret_name    = "${var.name}-mysql-admin-password"
  vault_id       = oci_kms_vault.main[0].id
  description    = "Admin password for the ${var.name} MySQL DB system."
  defined_tags   = local.common_defined_tags
  freeform_tags  = local.common_freeform_tags

  secret_content {
    content_type = "BASE64"
    content      = base64encode(local.mysql_admin_password)
    stage        = "CURRENT"
  }
}

# --- PostgreSQL admin password secret ---

resource "oci_vault_secret" "postgresql_admin_password" {
  count = local.needs_vault && var.features.postgresql ? 1 : 0

  compartment_id = var.compartment_id
  key_id         = oci_kms_key.secrets[0].id
  secret_name    = "${var.name}-postgresql-admin-password"
  vault_id       = oci_kms_vault.main[0].id
  description    = "Admin password for the ${var.name} PostgreSQL DB system."
  defined_tags   = local.common_defined_tags
  freeform_tags  = local.common_freeform_tags

  secret_content {
    content_type = "BASE64"
    content      = base64encode(local.postgresql_admin_password)
    stage        = "CURRENT"
  }
}
