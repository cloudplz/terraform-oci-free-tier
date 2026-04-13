resource "random_id" "suffix" {
  byte_length = 2
}

resource "random_password" "mysql_admin" {
  count = var.features.mysql && var.mysql_admin_password == null ? 1 : 0

  length           = 16
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "!#%&*()-_=+[]{}:?"
  special          = true
}

resource "random_password" "postgresql_admin" {
  count = var.features.postgresql && var.postgresql_admin_password == null ? 1 : 0

  length           = 16
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "!#%&*()-_=+[]{}:?"
  special          = true
}
