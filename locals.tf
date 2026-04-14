locals {
  compact_name = replace(var.name, "-", "")

  # OCI catalogs Ubuntu images under "Canonical Ubuntu".
  image_operating_system = "Canonical Ubuntu"

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

  # ---------------------------------------------------------------------------
  # Fleet profiles
  # ---------------------------------------------------------------------------
  profile_configs = {
    persistent = {
      compute_instances = {
        vm1 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
        vm2 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
      }
      amd_micro_instances = {}
      block_volumes = {
        data1 = { attach_to = "vm1", size_gb = 50, mount_point = "/data" }
        data2 = { attach_to = "vm2", size_gb = 50, mount_point = "/data" }
      }
    }

    balanced = {
      compute_instances = {
        vm1 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
        vm2 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
        vm3 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 12, ocpus = 2, subnet_role = "public" }
      }
      amd_micro_instances = {}
      block_volumes = {
        data1 = { attach_to = "vm1", size_gb = 50, mount_point = "/data" }
      }
    }

    complete = {
      compute_instances = {
        vm1 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
        vm2 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
        vm3 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 12, ocpus = 2, subnet_role = "public" }
      }
      amd_micro_instances = {
        micro1 = { assign_public_ip = true, boot_volume_gb = 50, subnet_role = "public" }
      }
      block_volumes = {}
    }

    compute-only = {
      compute_instances = {
        vm1 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
        vm2 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
        vm3 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
        vm4 = { assign_public_ip = true, boot_volume_gb = 50, memory_gb = 6, ocpus = 1, subnet_role = "public" }
      }
      amd_micro_instances = {}
      block_volumes       = {}
    }
  }

  # ---------------------------------------------------------------------------
  # Effective resource maps (variable overrides profile when non-null)
  # ---------------------------------------------------------------------------
  effective_compute_instances   = coalesce(var.compute_instances, local.profile_configs[var.profile].compute_instances)
  effective_amd_micro_instances = coalesce(var.amd_micro_instances, local.profile_configs[var.profile].amd_micro_instances)
  effective_block_volumes       = coalesce(var.block_volumes, local.profile_configs[var.profile].block_volumes)

  # Authoritative storage budget check (variable-level checks are best-effort).
  total_storage_gb = (
    sum([for i in values(local.effective_compute_instances) : i.boot_volume_gb]) +
    sum(concat([for i in values(local.effective_amd_micro_instances) : i.boot_volume_gb], [0])) +
    sum(concat([for v in values(local.effective_block_volumes) : v.size_gb], [0]))
  )

  # ---------------------------------------------------------------------------
  # A1 Compute
  # ---------------------------------------------------------------------------
  image_id = coalesce(var.image_id_override, try(data.oci_core_images.a1.images[0].id, null))

  instance_keys = sort(keys(local.effective_compute_instances))

  instance_hostname_labels = {
    for index, key in local.instance_keys : key => "vm${index + 1}"
  }

  instance_availability_domains = {
    for index, key in local.instance_keys : key => coalesce(
      try(local.effective_compute_instances[key].availability_domain, null),
      var.availability_domain,
      local.availability_domains[index % length(local.availability_domains)]
    )
  }

  # ---------------------------------------------------------------------------
  # Keepalive cloud-config
  # ---------------------------------------------------------------------------
  keepalive_cloud_config = <<-CLOUDCFG
    #cloud-config
    write_files:
      - path: /usr/local/bin/keepalive.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          timeout 300 bash -c 'cat /dev/zero | gzip > /dev/null' 2>/dev/null || true
          curl -sf -o /dev/null http://ifconfig.me || true
    runcmd:
      - echo '0 * * * * root /usr/local/bin/keepalive.sh >/dev/null 2>&1' > /etc/cron.d/keepalive
      - chmod 0644 /etc/cron.d/keepalive
  CLOUDCFG

  mime_boundary = "MIMEBOUNDARY_OCI_FREE_TIER"

  # ---------------------------------------------------------------------------
  # Block volume mount cloud-config (per A1 instance)
  #
  # Writes an idempotent mount script to /usr/local/bin/mount-block-volumes.sh
  # via write_files, then runs it once via runcmd. The script discovers
  # paravirtualized block devices that aren't the boot disk (using lsblk PKNAME
  # to identify the disk backing /), formats any that lack a filesystem, and
  # mounts them at the configured mount_points. If some mounts are missing
  # (e.g. volume not yet attached on first boot), a cron job retries every
  # 5 minutes. Once all mounts succeed the cron job removes itself.
  # ---------------------------------------------------------------------------
  _instance_mount_points = {
    for key in local.instance_keys : key => [
      for vk, vol in local.effective_block_volumes : vol.mount_point
      if vol.attach_to == key && vol.mount_point != null
    ]
  }

  _instance_mount_cloud_config = {
    for key in local.instance_keys : key => (
      length(local._instance_mount_points[key]) > 0
      ? trimspace(join("\n", [
        "#cloud-config",
        "write_files:",
        "  - path: /usr/local/bin/mount-block-volumes.sh",
        "    permissions: '0755'",
        "    content: |",
        "      #!/bin/bash",
        "      set -euo pipefail",
        "      BOOT_DISK=$(lsblk -nro PKNAME \"$(findmnt -n -o SOURCE /)\" | head -1)",
        "      MOUNT_POINTS=(${join(" ", [for mp in local._instance_mount_points[key] : "\"${mp}\""])})",
        "      IDX=0",
        "      for DEV in $(lsblk -dnpo NAME,TYPE | awk '$2==\"disk\"{print $1}'); do",
        "        [ \"$(basename \"$DEV\")\" = \"$BOOT_DISK\" ] && continue",
        "        [ \"$IDX\" -ge \"$${#MOUNT_POINTS[@]}\" ] && break",
        "        MP=\"$${MOUNT_POINTS[$IDX]}\"",
        "        if ! blkid \"$DEV\" >/dev/null 2>&1; then",
        "          mkfs.ext4 -q \"$DEV\"",
        "        fi",
        "        mkdir -p \"$MP\"",
        "        if ! mountpoint -q \"$MP\"; then",
        "          if mount \"$DEV\" \"$MP\"; then",
        "            UUID=$(blkid -s UUID -o value \"$DEV\")",
        "            grep -q \"$UUID\" /etc/fstab 2>/dev/null || echo \"UUID=$UUID $MP ext4 defaults,nofail 0 2\" >> /etc/fstab",
        "          fi",
        "        fi",
        "        IDX=$((IDX + 1))",
        "      done",
        "      ALL_MOUNTED=true",
        "      for MP in \"$${MOUNT_POINTS[@]}\"; do",
        "        mountpoint -q \"$MP\" || ALL_MOUNTED=false",
        "      done",
        "      if $ALL_MOUNTED; then",
        "        rm -f /etc/cron.d/mount-block-volumes",
        "      else",
        "        echo '*/5 * * * * root /usr/local/bin/mount-block-volumes.sh >/dev/null 2>&1' > /etc/cron.d/mount-block-volumes",
        "        chmod 0644 /etc/cron.d/mount-block-volumes",
        "      fi",
        "runcmd:",
        "  - /usr/local/bin/mount-block-volumes.sh",
      ]))
      : null
    )
  }

  # ---------------------------------------------------------------------------
  # User data composition (A1 instances)
  #
  # Collects up to three cloud-init parts per instance: keepalive, block volume
  # mount cloud-config, and user-provided data. A single part is passed through
  # as-is; multiple parts are wrapped in a multipart MIME envelope.
  # ---------------------------------------------------------------------------
  _instance_raw_user_data = {
    for key in local.instance_keys : key => (
      try(local.effective_compute_instances[key].user_data, null) != null
      ? local.effective_compute_instances[key].user_data
      : var.user_data
    )
  }

  _instance_cloud_init_parts = {
    for key in local.instance_keys : key => concat(
      var.enable_keepalive ? [{
        content_type = "text/cloud-config"
        body         = trimspace(local.keepalive_cloud_config)
      }] : [],
      local._instance_mount_cloud_config[key] != null ? [{
        content_type = "text/cloud-config"
        body         = local._instance_mount_cloud_config[key]
      }] : [],
      local._instance_raw_user_data[key] != null ? [{
        content_type = startswith(trimspace(local._instance_raw_user_data[key]), "#cloud-config") ? "text/cloud-config" : "text/x-shellscript"
        body         = trimspace(local._instance_raw_user_data[key])
      }] : [],
    )
  }

  instance_user_data = {
    for key in local.instance_keys : key => (
      length(local._instance_cloud_init_parts[key]) == 0
      ? null
      : length(local._instance_cloud_init_parts[key]) == 1
      ? local._instance_cloud_init_parts[key][0].body
      : join("\n", concat(
        [
          "Content-Type: multipart/mixed; boundary=\"${local.mime_boundary}\"",
          "MIME-Version: 1.0",
          "",
        ],
        flatten([
          for part in local._instance_cloud_init_parts[key] : [
            "--${local.mime_boundary}",
            "Content-Type: ${part.content_type}; charset=\"us-ascii\"",
            "MIME-Version: 1.0",
            "",
            part.body,
            "",
          ]
        ]),
        ["--${local.mime_boundary}--", ""],
      ))
    )
  }

  # ---------------------------------------------------------------------------
  # AMD Micro Compute
  # ---------------------------------------------------------------------------
  micro_image_id = try(data.oci_core_images.micro[0].images[0].id, null)

  micro_keys = sort(keys(local.effective_amd_micro_instances))

  micro_hostname_labels = {
    for index, key in local.micro_keys : key => "micro${index + 1}"
  }

  micro_availability_domains = {
    for key in local.micro_keys : key => coalesce(try(local.effective_amd_micro_instances[key].availability_domain, null), local.availability_domain)
  }

  # User data for micro instances (module-level user_data + keepalive; no block
  # volumes since block volumes can only attach to A1 instances).
  _micro_cloud_init_parts = {
    for key in local.micro_keys : key => concat(
      var.enable_keepalive ? [{
        content_type = "text/cloud-config"
        body         = trimspace(local.keepalive_cloud_config)
      }] : [],
      var.user_data != null ? [{
        content_type = startswith(trimspace(var.user_data), "#cloud-config") ? "text/cloud-config" : "text/x-shellscript"
        body         = trimspace(var.user_data)
      }] : [],
    )
  }

  micro_user_data = {
    for key in local.micro_keys : key => (
      length(local._micro_cloud_init_parts[key]) == 0
      ? null
      : length(local._micro_cloud_init_parts[key]) == 1
      ? local._micro_cloud_init_parts[key][0].body
      : join("\n", concat(
        [
          "Content-Type: multipart/mixed; boundary=\"${local.mime_boundary}\"",
          "MIME-Version: 1.0",
          "",
        ],
        flatten([
          for part in local._micro_cloud_init_parts[key] : [
            "--${local.mime_boundary}",
            "Content-Type: ${part.content_type}; charset=\"us-ascii\"",
            "MIME-Version: 1.0",
            "",
            part.body,
            "",
          ]
        ]),
        ["--${local.mime_boundary}--", ""],
      ))
    )
  }

  # ---------------------------------------------------------------------------
  # NAT Gateway
  # ---------------------------------------------------------------------------
  needs_nat_gateway = anytrue(concat(
    [for i in values(local.effective_compute_instances) : try(i.subnet_role, "public") == "private"],
    [for i in values(local.effective_amd_micro_instances) : try(i.subnet_role, "public") == "private"],
  ))

  # ---------------------------------------------------------------------------
  # Load Balancer
  # ---------------------------------------------------------------------------
  lb_backend_keys = var.features.load_balancer ? (
    var.load_balancer_backend_instance_keys != null ? var.load_balancer_backend_instance_keys : toset(keys(local.effective_compute_instances))
  ) : toset([])

  nlb_backend_keys = var.features.network_load_balancer ? toset(keys(local.effective_compute_instances)) : toset([])

  # ---------------------------------------------------------------------------
  # Object Storage
  # ---------------------------------------------------------------------------
  bucket_name = lower(coalesce(var.object_storage_bucket_name, "${var.name}-${random_id.suffix.hex}"))

  # ---------------------------------------------------------------------------
  # Vault
  # ---------------------------------------------------------------------------
  needs_vault = var.features.vault && (var.features.mysql || var.features.postgresql)

  # ---------------------------------------------------------------------------
  # MySQL
  # ---------------------------------------------------------------------------
  mysql_admin_password = var.mysql_admin_password != null ? var.mysql_admin_password : try(random_password.mysql_admin[0].result, null)

  # ---------------------------------------------------------------------------
  # PostgreSQL
  # ---------------------------------------------------------------------------
  postgresql_admin_password = var.postgresql_admin_password != null ? var.postgresql_admin_password : try(random_password.postgresql_admin[0].result, null)

  # ---------------------------------------------------------------------------
  # Boot Volume Backup
  # ---------------------------------------------------------------------------
  bronze_backup_policy_id = var.features.boot_volume_backup ? try(
    [for p in data.oci_core_volume_backup_policies.oracle_defined[0].volume_backup_policies : p.id if p.display_name == "bronze"][0],
    null
  ) : null
}
