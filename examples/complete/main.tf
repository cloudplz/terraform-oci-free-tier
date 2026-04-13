provider "oci" {
  region = var.region
}

module "free_tier" {
  source = "../../"

  name           = "homelab"
  compartment_id = var.compartment_id
  ssh_public_key = var.ssh_public_key
  tenancy_id     = var.tenancy_id
}
