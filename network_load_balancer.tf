# Always Free: 1 network load balancer is free. The module creates at most 1.
# NLBs have no bandwidth shape constraint; the free-tier limit is 1 instance.
resource "oci_network_load_balancer_network_load_balancer" "main" {
  count = var.features.network_load_balancer ? 1 : 0

  compartment_id                 = var.compartment_id
  defined_tags                   = local.common_defined_tags
  display_name                   = "${var.name}-nlb"
  freeform_tags                  = local.common_freeform_tags
  is_preserve_source_destination = false
  is_private                     = false
  network_security_group_ids     = [oci_core_network_security_group.network_load_balancer[0].id]
  subnet_id                      = oci_core_subnet.public.id
}

resource "oci_network_load_balancer_backend_set" "main" {
  count = var.features.network_load_balancer ? 1 : 0

  name                     = "default-backend-set"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.main[0].id
  policy                   = "FIVE_TUPLE"

  health_checker {
    port     = var.network_load_balancer_port
    protocol = "TCP"
  }
}

resource "oci_network_load_balancer_backend" "main" {
  for_each = local.nlb_backend_keys

  backend_set_name         = oci_network_load_balancer_backend_set.main[0].name
  ip_address               = oci_core_instance.vm[each.key].private_ip
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.main[0].id
  port                     = var.network_load_balancer_port
}

resource "oci_network_load_balancer_listener" "main" {
  count = var.features.network_load_balancer ? 1 : 0

  default_backend_set_name = oci_network_load_balancer_backend_set.main[0].name
  name                     = "tcp"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.main[0].id
  port                     = var.network_load_balancer_port
  protocol                 = "TCP"
}
