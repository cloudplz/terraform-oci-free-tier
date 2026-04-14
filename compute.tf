# Always Free: VM.Standard.A1.Flex is the Always Free Arm shape. Charges are
# impossible as long as the total fleet stays within 4 OCPUs, 24 GB RAM, and
# 200 GB boot volume -- all enforced by variable validation.
resource "oci_core_instance" "vm" {
  for_each = local.effective_compute_instances

  availability_domain = local.instance_availability_domains[each.key]
  compartment_id      = var.compartment_id
  defined_tags        = local.common_defined_tags
  display_name        = "${var.name}-${each.key}"
  freeform_tags       = merge(local.common_freeform_tags, { Role = each.key })
  shape               = "VM.Standard.A1.Flex"

  create_vnic_details {
    assign_public_ip = try(each.value.assign_public_ip, true)
    display_name     = "${var.name}-${each.key}-vnic"
    hostname_label   = local.instance_hostname_labels[each.key]
    nsg_ids          = [oci_core_network_security_group.compute.id]
    subnet_id        = try(each.value.subnet_role, "public") == "private" ? oci_core_subnet.private.id : oci_core_subnet.public.id
  }

  metadata = merge(
    {
      ssh_authorized_keys = trimspace(var.ssh_public_key)
    },
    local.instance_user_data[each.key] == null ? {} : { user_data = base64encode(local.instance_user_data[each.key]) },
  )

  shape_config {
    memory_in_gbs = each.value.memory_gb
    ocpus         = each.value.ocpus
  }

  source_details {
    boot_volume_size_in_gbs = each.value.boot_volume_gb
    boot_volume_vpus_per_gb = 10
    source_id               = local.image_id
    source_type             = "image"
  }

  lifecycle {
    ignore_changes = [source_details[0].source_id, defined_tags]

    precondition {
      condition     = local.image_id != null
      error_message = "No Ubuntu ${var.operating_system_version} image found for VM.Standard.A1.Flex."
    }
  }
}

# Always Free: VM.Standard.E2.1.Micro is the Always Free AMD shape (1/8 OCPU,
# 1 GB RAM, fixed). Up to 2 instances allowed; enforced by variable validation.
resource "oci_core_instance" "micro" {
  for_each = local.effective_amd_micro_instances

  availability_domain = local.micro_availability_domains[each.key]
  compartment_id      = var.compartment_id
  defined_tags        = local.common_defined_tags
  display_name        = "${var.name}-${each.key}"
  freeform_tags       = merge(local.common_freeform_tags, { Role = each.key })
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    assign_public_ip = try(each.value.assign_public_ip, true)
    display_name     = "${var.name}-${each.key}-vnic"
    hostname_label   = local.micro_hostname_labels[each.key]
    nsg_ids          = [oci_core_network_security_group.compute.id]
    subnet_id        = try(each.value.subnet_role, "public") == "private" ? oci_core_subnet.private.id : oci_core_subnet.public.id
  }

  metadata = merge(
    {
      ssh_authorized_keys = trimspace(var.ssh_public_key)
    },
    local.micro_user_data[each.key] == null ? {} : { user_data = base64encode(local.micro_user_data[each.key]) },
  )

  source_details {
    boot_volume_size_in_gbs = each.value.boot_volume_gb
    boot_volume_vpus_per_gb = 10
    source_id               = local.micro_image_id
    source_type             = "image"
  }

  lifecycle {
    ignore_changes = [source_details[0].source_id, defined_tags]

    precondition {
      condition     = local.micro_image_id != null
      error_message = "No Ubuntu ${var.operating_system_version} image found for VM.Standard.E2.1.Micro."
    }
  }
}

# ---------------------------------------------------------------------------
# Block Volumes (Always Free: shares the 200 GB budget with boot volumes)
# ---------------------------------------------------------------------------
resource "oci_core_volume" "data" {
  for_each = local.effective_block_volumes

  availability_domain = oci_core_instance.vm[each.value.attach_to].availability_domain
  compartment_id      = var.compartment_id
  defined_tags        = local.common_defined_tags
  display_name        = "${var.name}-${each.key}"
  freeform_tags       = local.common_freeform_tags
  size_in_gbs         = each.value.size_gb
  vpus_per_gb         = 10

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_volume_attachment" "data" {
  for_each = local.effective_block_volumes

  attachment_type = "paravirtualized"
  instance_id    = oci_core_instance.vm[each.value.attach_to].id
  volume_id      = oci_core_volume.data[each.key].id
}
