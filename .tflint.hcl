config {
  call_module_type    = "none"
  force               = false
  disabled_by_default = false
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = false # per-service files (compute.tf, network.tf, etc.) instead of a single main.tf
}
