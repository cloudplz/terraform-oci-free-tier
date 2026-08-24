# Regression: multiple text/cloud-config parts in a multipart MIME envelope
# shadow each other unless each module-generated part carries merge_how
# (list-append semantics). vm9-style fleet (keepalive + block-volume mount)
# previously lost the keepalive part silently.

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

  compute_instances = {
    vm9 = { boot_volume_gb = 50, memory_gb = 6, ocpus = 1 }
  }

  block_volumes = {
    data9 = { attach_to = "vm9", size_gb = 50, mount_point = "/data" }
  }

  amd_micro_instances = {
    micro9 = { boot_volume_gb = 50 }
  }
}

run "multipart_parts_carry_merge_how" {
  command = plan

  assert {
    condition = alltrue([
      for part in local.instance_cloud_init_parts["vm9"] :
      part.content_type != "text/cloud-config" || contains(split("\n", part.body), "merge_how:")
    ])
    error_message = "Every module-generated text/cloud-config part must carry merge_how so multipart parts compose instead of shadowing."
  }

  assert {
    condition = alltrue([
      for part in local.micro_cloud_init_parts["micro9"] :
      part.content_type != "text/cloud-config" || contains(split("\n", part.body), "merge_how:")
    ])
    error_message = "Micro instance module-generated cloud-config parts must carry merge_how too."
  }
}

run "user_part_precedes_module_parts" {
  command = plan

  variables {
    user_data = "#!/bin/bash\necho user-part-first\n"
  }

  assert {
    condition     = local.instance_cloud_init_parts["vm9"][0].content_type == "text/x-shellscript"
    error_message = "User-provided part must come first so module parts never override explicit user input."
  }
}

run "hostname_label_matches_instance_key" {
  command = plan

  assert {
    condition     = local.instance_hostname_labels["vm9"] == "vm9"
    error_message = "hostname_label must equal the instance key so OS hostnames are unique across tenancies."
  }

  assert {
    condition     = local.micro_hostname_labels["micro9"] == "micro9"
    error_message = "Micro hostname_label must equal the instance key."
  }
}
