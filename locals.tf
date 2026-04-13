locals {
  compact_name = replace(var.name, "-", "")

  # OCI often reports Ubuntu platform images as "Canonical Ubuntu" in the image catalog,
  # so normalize the friendly module input before querying the data source.
  image_operating_system = var.operating_system == "Ubuntu" ? "Canonical Ubuntu" : var.operating_system

  common_defined_tags = var.defined_tags

  common_freeform_tags = merge({
    ManagedBy = "terraform"
    Project   = var.name
    Tier      = "always-free"
  }, var.freeform_tags)

  availability_domains = data.oci_identity_availability_domains.available.availability_domains[*].name
  availability_domain  = coalesce(var.availability_domain, local.availability_domains[0])

  # --- Home region detection (P0) ---
  # AD names follow the format "{prefix}:{REGION_KEY}-AD-{N}", e.g. "kIdk:PHX-AD-1".
  current_region_key = try(
    upper(split("-AD-", split(":", data.oci_identity_availability_domains.available.availability_domains[0].name)[1])[0]),
    null
  )

  home_region_key = try(
    [for r in data.oci_identity_region_subscriptions.home[0].region_subscriptions : upper(r.region_key) if r.is_home_region][0],
    null
  )

  cidr_inputs = {
    private = var.private_subnet_cidr
    public  = var.public_subnet_cidr
    vcn     = var.vcn_cidr
  }

  cidr_prefix_lengths = {
    for name, cidr in local.cidr_inputs : name => tonumber(split("/", cidr)[1])
  }

  cidr_octets = {
    for name, cidr in local.cidr_inputs : name => [for octet in split(".", cidrhost(cidr, 0)) : tonumber(octet)]
  }

  cidr_ranges = {
    for name, octets in local.cidr_octets : name => {
      start = sum([
        for index, octet in octets :
        octet * element([16777216, 65536, 256, 1], index)
      ])
      end = sum([
        for index, octet in octets :
        octet * element([16777216, 65536, 256, 1], index)
      ]) + pow(2, 32 - local.cidr_prefix_lengths[name]) - 1
    }
  }

  # --- A1 Compute ---
  image_id = coalesce(var.image_id_override, try(data.oci_core_images.a1.images[0].id, null))

  instance_keys = sort(keys(var.compute_instances))

  instance_hostname_labels = {
    for index, key in local.instance_keys : key => "vm${index + 1}"
  }

  instance_availability_domains = {
    for index, key in local.instance_keys : key => coalesce(
      try(var.compute_instances[key].availability_domain, null),
      var.availability_domain,
      local.availability_domains[index % length(local.availability_domains)]
    )
  }

  instance_user_data = {
    for key in local.instance_keys : key => (
      try(var.compute_instances[key].user_data, null) != null
      ? var.compute_instances[key].user_data
      : var.user_data
    )
  }

  # --- AMD Micro Compute ---
  micro_image_id = try(data.oci_core_images.micro[0].images[0].id, null)

  micro_keys = sort(keys(var.amd_micro_instances))

  micro_hostname_labels = {
    for index, key in local.micro_keys : key => "micro${index + 1}"
  }

  micro_availability_domains = {
    for key in local.micro_keys : key => coalesce(try(var.amd_micro_instances[key].availability_domain, null), local.availability_domain)
  }

  # --- NAT Gateway ---
  needs_nat_gateway = anytrue(concat(
    [for i in values(var.compute_instances) : try(i.subnet_role, "public") == "private"],
    [for i in values(var.amd_micro_instances) : try(i.subnet_role, "public") == "private"],
  ))

  # --- Load Balancer ---
  lb_backend_keys = var.features.load_balancer ? (
    var.load_balancer_backend_instance_keys != null ? var.load_balancer_backend_instance_keys : toset(keys(var.compute_instances))
  ) : toset([])

  nlb_backend_keys = var.features.network_load_balancer ? toset(keys(var.compute_instances)) : toset([])

  # --- Object Storage ---
  bucket_name = lower(coalesce(var.object_storage_bucket_name, "${var.name}-${random_id.suffix.hex}"))

  # --- Vault ---
  needs_vault = var.features.vault && (var.features.mysql || var.features.postgresql)

  # --- MySQL ---
  mysql_admin_password = var.mysql_admin_password != null ? var.mysql_admin_password : try(random_password.mysql_admin[0].result, null)

  # --- PostgreSQL ---
  postgresql_admin_password = var.postgresql_admin_password != null ? var.postgresql_admin_password : try(random_password.postgresql_admin[0].result, null)

  # --- Boot Volume Backup ---
  bronze_backup_policy_id = var.features.boot_volume_backup ? try(
    [for p in data.oci_core_volume_backup_policies.oracle_defined[0].volume_backup_policies : p.id if p.display_name == "bronze"][0],
    null
  ) : null
}
