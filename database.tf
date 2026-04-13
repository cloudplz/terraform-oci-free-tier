# -----------------------------------------------------------------------------
# MySQL DB System (Always Free)
# -----------------------------------------------------------------------------

# Always Free: the MySQL.Free shape is exclusively for the Always Free tier.
# OCI does not allow paid workloads on this shape, so charges are structurally
# impossible as long as shape_name remains "MySQL.Free". Fixed at 50 GB storage
# and 8 GB RAM with no HA. Note: the separate Always Free HeatWave cluster
# (HeatWave.Free shape) is not yet implemented by this module.
resource "oci_mysql_mysql_db_system" "main" {
  count = var.features.mysql ? 1 : 0

  admin_password          = local.mysql_admin_password
  admin_username          = var.mysql_admin_username
  availability_domain     = local.availability_domain
  compartment_id          = var.compartment_id
  data_storage_size_in_gb = 50
  defined_tags            = local.common_defined_tags
  display_name            = "${var.name}-mysql"
  freeform_tags           = local.common_freeform_tags
  hostname_label          = "mysql"
  is_highly_available     = false
  shape_name              = "MySQL.Free"
  subnet_id               = oci_core_subnet.private.id

  lifecycle {
    ignore_changes = [mysql_version]
  }
}

# -----------------------------------------------------------------------------
# PostgreSQL
# -----------------------------------------------------------------------------

# CHARGE WARNING: OCI Database with PostgreSQL is NOT Always Free. Defaults to
# the smallest flex shape (1 OCPU / 16 GB) but still incurs hourly compute and
# storage charges. Only enable this if you accept the cost.
resource "oci_psql_db_system" "main" {
  count = var.features.postgresql ? 1 : 0

  compartment_id              = var.compartment_id
  db_version                  = var.postgresql_db_version
  defined_tags                = local.common_defined_tags
  display_name                = "${var.name}-postgresql"
  freeform_tags               = local.common_freeform_tags
  instance_count              = 1
  instance_memory_size_in_gbs = var.postgresql_instance_memory_size_in_gbs
  instance_ocpu_count         = var.postgresql_instance_ocpu_count
  shape                       = var.postgresql_shape

  credentials {
    username = var.postgresql_admin_username
    password_details {
      password_type = "PLAIN_TEXT"
      password      = local.postgresql_admin_password
    }
  }

  network_details {
    subnet_id = oci_core_subnet.private.id
  }

  storage_details {
    availability_domain   = local.availability_domain
    is_regionally_durable = false
    system_type           = "OCI_OPTIMIZED_STORAGE"
  }

  lifecycle {
    ignore_changes = [db_version]
  }
}
