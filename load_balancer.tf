# Always Free: 1 flexible load balancer at 10 Mbps is free. The shape is
# hardcoded below to 10/10 Mbps. Charges are impossible at this bandwidth.
resource "oci_load_balancer_load_balancer" "main" {
  count = var.features.load_balancer ? 1 : 0

  compartment_id             = var.compartment_id
  defined_tags               = local.common_defined_tags
  display_name               = "${var.name}-lb"
  freeform_tags              = local.common_freeform_tags
  is_private                 = false
  network_security_group_ids = [oci_core_network_security_group.load_balancer[0].id]
  shape                      = "flexible"
  subnet_ids                 = [oci_core_subnet.public.id]

  shape_details {
    maximum_bandwidth_in_mbps = 10
    minimum_bandwidth_in_mbps = 10
  }
}

resource "oci_load_balancer_backend_set" "main" {
  count = var.features.load_balancer ? 1 : 0

  load_balancer_id = oci_load_balancer_load_balancer.main[0].id
  name             = "default-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    port     = var.load_balancer_backend_port
    protocol = "TCP"
  }
}

resource "oci_load_balancer_backend" "main" {
  for_each = local.lb_backend_keys

  backendset_name  = oci_load_balancer_backend_set.main[0].name
  ip_address       = oci_core_instance.vm[each.key].private_ip
  load_balancer_id = oci_load_balancer_load_balancer.main[0].id
  port             = var.load_balancer_backend_port
}

resource "oci_load_balancer_listener" "http" {
  count = var.features.load_balancer ? 1 : 0

  default_backend_set_name = oci_load_balancer_backend_set.main[0].name
  load_balancer_id         = oci_load_balancer_load_balancer.main[0].id
  name                     = "http"
  port                     = var.load_balancer_listener_port
  protocol                 = "HTTP"
}
