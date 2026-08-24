# Newer OCI regions (e.g. us-sanjose-1) embed the full region name in AD names
# ("kvUq:US-SANJOSE-1-AD-1") instead of the 3-letter key ("kIdk:PHX-AD-1").
# The home_region check must accept a match on either the key or the full name.

mock_provider "oci" {
  mock_data "oci_core_images" {
    defaults = {
      images = [
        {
          id                       = "ocid1.image.oc1.testalwaysfree"
          operating_system         = "Ubuntu"
          operating_system_version = "24.04"
        }
      ]
    }
  }

  mock_data "oci_identity_availability_domains" {
    defaults = {
      availability_domains = [
        {
          name = "kvUq:US-SANJOSE-1-AD-1"
        }
      ]
    }
  }

  mock_data "oci_objectstorage_namespace" {
    defaults = {
      namespace = "testnamespace"
    }
  }

  mock_data "oci_identity_region_subscriptions" {
    defaults = {
      region_subscriptions = [
        {
          is_home_region = true
          region_key     = "SJC"
          region_name    = "us-sanjose-1"
          status         = "READY"
        }
      ]
    }
  }
}

mock_provider "random" {}

variables {
  compartment_id = "ocid1.compartment.oc1..exampleuniqueID"
  name           = "test"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakePublicKeyForTests user@example"
  tenancy_id     = "ocid1.tenancy.oc1..exampleuniqueID"
}

run "home_region_check_accepts_new_region_ad_names" {
  command = plan

  assert {
    condition     = local.current_region_key == "US-SANJOSE-1"
    error_message = "current_region_key should extract the full region name from new-style AD names."
  }

  assert {
    condition     = local.home_region_name == "US-SANJOSE-1"
    error_message = "home_region_name should mirror the home region's full name."
  }
}

run "budget_created_when_tenancy_id_set" {
  command = plan

  assert {
    condition     = length(oci_budget_budget.free_tier) == 1
    error_message = "Budget should be created when tenancy_id is set."
  }
}
