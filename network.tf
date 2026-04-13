# Always Free: VCNs and all networking components (subnets, gateways, route
# tables, security lists, NSGs) are included. Up to 2 VCNs per tenancy.
resource "oci_core_vcn" "main" {
  cidr_blocks    = [var.vcn_cidr]
  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-vcn"
  dns_label      = substr(local.compact_name, 0, 15)
  freeform_tags  = local.common_freeform_tags
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-igw"
  enabled        = true
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id
}

resource "oci_core_nat_gateway" "main" {
  count = local.needs_nat_gateway ? 1 : 0

  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-natgw"
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-private-rt"
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id

  dynamic "route_rules" {
    for_each = local.needs_nat_gateway ? [1] : []
    content {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_nat_gateway.main[0].id
    }
  }
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-public-rt"
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_subnet" "private" {
  cidr_block                 = var.private_subnet_cidr
  compartment_id             = var.compartment_id
  defined_tags               = local.common_defined_tags
  display_name               = "${var.name}-private-subnet"
  dns_label                  = "private"
  freeform_tags              = local.common_freeform_tags
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids = concat(
    [oci_core_vcn.main.default_security_list_id],
    var.features.mysql ? [oci_core_security_list.mysql[0].id] : [],
    var.features.postgresql ? [oci_core_security_list.postgresql[0].id] : []
  )
  vcn_id = oci_core_vcn.main.id

  lifecycle {
    precondition {
      condition = (
        local.cidr_ranges.private.start >= local.cidr_ranges.vcn.start &&
        local.cidr_ranges.private.end <= local.cidr_ranges.vcn.end
      )
      error_message = "private_subnet_cidr must be fully contained within vcn_cidr."
    }

    precondition {
      condition = (
        local.cidr_ranges.private.end < local.cidr_ranges.public.start ||
        local.cidr_ranges.public.end < local.cidr_ranges.private.start
      )
      error_message = "private_subnet_cidr and public_subnet_cidr must not overlap."
    }
  }
}

resource "oci_core_subnet" "public" {
  cidr_block                 = var.public_subnet_cidr
  compartment_id             = var.compartment_id
  defined_tags               = local.common_defined_tags
  display_name               = "${var.name}-public-subnet"
  dns_label                  = "public"
  freeform_tags              = local.common_freeform_tags
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_vcn.main.default_security_list_id]
  vcn_id                     = oci_core_vcn.main.id

  lifecycle {
    precondition {
      condition = (
        local.cidr_ranges.public.start >= local.cidr_ranges.vcn.start &&
        local.cidr_ranges.public.end <= local.cidr_ranges.vcn.end
      )
      error_message = "public_subnet_cidr must be fully contained within vcn_cidr."
    }
  }
}

# -----------------------------------------------------------------------------
# Compute NSG
# -----------------------------------------------------------------------------

resource "oci_core_network_security_group" "compute" {
  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-compute-nsg"
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id
}

resource "oci_core_network_security_group_security_rule" "compute_egress_all" {
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  direction                 = "EGRESS"
  network_security_group_id = oci_core_network_security_group.compute.id
  protocol                  = "all"
}

resource "oci_core_network_security_group_security_rule" "compute_ingress_ssh" {
  count = var.ssh_ingress_cidr == null ? 0 : 1

  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.compute.id
  protocol                  = "6"
  source                    = var.ssh_ingress_cidr
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      max = 22
      min = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "compute_ingress_icmp" {
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.compute.id
  protocol                  = "1"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "compute_ingress_icmp_echo" {
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.compute.id
  protocol                  = "1"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"

  icmp_options {
    type = 8
  }
}

# -----------------------------------------------------------------------------
# Flexible Load Balancer NSG
# -----------------------------------------------------------------------------

resource "oci_core_network_security_group" "load_balancer" {
  count = var.features.load_balancer ? 1 : 0

  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-lb-nsg"
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id
}

resource "oci_core_network_security_group_security_rule" "compute_ingress_load_balancer" {
  count = var.features.load_balancer ? 1 : 0

  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.compute.id
  protocol                  = "6"
  source                    = oci_core_network_security_group.load_balancer[0].id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      max = var.load_balancer_backend_port
      min = var.load_balancer_backend_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "load_balancer_egress_backend" {
  count = var.features.load_balancer ? 1 : 0

  destination               = oci_core_network_security_group.compute.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  direction                 = "EGRESS"
  network_security_group_id = oci_core_network_security_group.load_balancer[0].id
  protocol                  = "6"

  tcp_options {
    destination_port_range {
      max = var.load_balancer_backend_port
      min = var.load_balancer_backend_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "load_balancer_ingress_listener" {
  count = var.features.load_balancer ? 1 : 0

  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.load_balancer[0].id
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      max = var.load_balancer_listener_port
      min = var.load_balancer_listener_port
    }
  }
}

# -----------------------------------------------------------------------------
# Network Load Balancer NSG
# -----------------------------------------------------------------------------

resource "oci_core_network_security_group" "network_load_balancer" {
  count = var.features.network_load_balancer ? 1 : 0

  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-nlb-nsg"
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id
}

resource "oci_core_network_security_group_security_rule" "compute_ingress_nlb" {
  count = var.features.network_load_balancer ? 1 : 0

  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.compute.id
  protocol                  = "6"
  source                    = oci_core_network_security_group.network_load_balancer[0].id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      max = var.network_load_balancer_port
      min = var.network_load_balancer_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nlb_egress_backend" {
  count = var.features.network_load_balancer ? 1 : 0

  destination               = oci_core_network_security_group.compute.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  direction                 = "EGRESS"
  network_security_group_id = oci_core_network_security_group.network_load_balancer[0].id
  protocol                  = "6"

  tcp_options {
    destination_port_range {
      max = var.network_load_balancer_port
      min = var.network_load_balancer_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nlb_ingress_listener" {
  count = var.features.network_load_balancer ? 1 : 0

  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.network_load_balancer[0].id
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      max = var.network_load_balancer_port
      min = var.network_load_balancer_port
    }
  }
}

# -----------------------------------------------------------------------------
# MySQL Security List
# -----------------------------------------------------------------------------

resource "oci_core_security_list" "mysql" {
  count = var.features.mysql ? 1 : 0

  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-mysql-sl"
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id

  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    description = "MySQL classic protocol from VCN"

    tcp_options {
      min = 3306
      max = 3306
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    description = "MySQL X Protocol from VCN"

    tcp_options {
      min = 33060
      max = 33060
    }
  }
}

# -----------------------------------------------------------------------------
# PostgreSQL Security List
# -----------------------------------------------------------------------------

resource "oci_core_security_list" "postgresql" {
  count = var.features.postgresql ? 1 : 0

  compartment_id = var.compartment_id
  defined_tags   = local.common_defined_tags
  display_name   = "${var.name}-postgresql-sl"
  freeform_tags  = local.common_freeform_tags
  vcn_id         = oci_core_vcn.main.id

  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    description = "PostgreSQL from VCN"

    tcp_options {
      min = 5432
      max = 5432
    }
  }
}
