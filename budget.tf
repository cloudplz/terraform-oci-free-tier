# Always Free: OCI budgets and alert rules are free to create and do not count
# against any service quota. The alert fires when actual spending reaches the
# monthly budget amount ($1 by default). Adjust var.budget_amount as needed.
resource "oci_budget_budget" "free_tier" {
  count = var.features.budget && var.tenancy_id != null ? 1 : 0

  amount         = var.budget_amount
  compartment_id = var.tenancy_id
  defined_tags   = local.common_defined_tags
  description    = "Safety-net budget for Always Free resources. Alert fires when spending reaches the budget amount."
  display_name   = "${var.name}-free-tier-budget"
  freeform_tags  = local.common_freeform_tags
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_id]
}

resource "oci_budget_alert_rule" "any_spending" {
  count = var.features.budget && var.tenancy_id != null && var.budget_alert_email != null ? 1 : 0

  budget_id      = oci_budget_budget.free_tier[0].id
  display_name   = "${var.name}-any-spending-alert"
  message        = "WARNING: Spending detected on compartment targeted by the ${var.name} free-tier module. Review your OCI console Cost Analysis to identify the source."
  recipients     = var.budget_alert_email
  threshold      = 100
  threshold_type = "PERCENTAGE"
  type           = "ACTUAL"
}
