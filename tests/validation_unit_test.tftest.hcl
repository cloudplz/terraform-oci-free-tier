mock_provider "oci" {
  mock_data "oci_core_images" {
    defaults = {
      images = [
        {
          id = "ocid1.image.oc1.testalwaysfree"
        }
      ]
    }
  }

  mock_data "oci_identity_availability_domains" {
    defaults = {
      availability_domains = [
        {
          name = "kIdk:PHX-AD-1"
        }
      ]
    }
  }

  mock_data "oci_objectstorage_namespace" {
    defaults = {
      namespace = "testnamespace"
    }
  }

  mock_data "oci_core_volume_backup_policies" {
    defaults = {
      volume_backup_policies = [
        {
          id           = "ocid1.volumebackuppolicy.oc1..bronze"
          display_name = "bronze"
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
}

run "rejects_more_than_four_ocpus" {
  command = plan

  variables {
    compute_instances = {
      vm1 = {
        assign_public_ip = true
        boot_volume_gb   = 50
        memory_gb        = 6
        ocpus            = 2
        subnet_role      = "public"
      }
      vm2 = {
        assign_public_ip = true
        boot_volume_gb   = 50
        memory_gb        = 6
        ocpus            = 2
        subnet_role      = "public"
      }
      vm3 = {
        assign_public_ip = true
        boot_volume_gb   = 50
        memory_gb        = 6
        ocpus            = 1
        subnet_role      = "public"
      }
    }
  }

  expect_failures = [var.compute_instances]
}

run "rejects_more_than_two_hundred_gb_of_storage" {
  command = plan

  variables {
    compute_instances = {
      vm1 = {
        assign_public_ip = true
        boot_volume_gb   = 75
        memory_gb        = 6
        ocpus            = 1
        subnet_role      = "public"
      }
      vm2 = {
        assign_public_ip = true
        boot_volume_gb   = 75
        memory_gb        = 6
        ocpus            = 1
        subnet_role      = "public"
      }
      vm3 = {
        assign_public_ip = true
        boot_volume_gb   = 75
        memory_gb        = 12
        ocpus            = 2
        subnet_role      = "public"
      }
    }
  }

  expect_failures = [var.compute_instances]
}

run "rejects_private_instances_requesting_public_ips" {
  command = plan

  variables {
    compute_instances = {
      vm1 = {
        assign_public_ip = true
        boot_volume_gb   = 50
        memory_gb        = 6
        ocpus            = 1
        subnet_role      = "private"
      }
    }
  }

  expect_failures = [var.compute_instances]
}

run "rejects_more_than_two_amd_micro_instances" {
  command = plan

  variables {
    compute_instances = {
      vm1 = {
        assign_public_ip = true
        boot_volume_gb   = 50
        memory_gb        = 24
        ocpus            = 4
        subnet_role      = "public"
      }
    }

    amd_micro_instances = {
      micro1 = { boot_volume_gb = 50 }
      micro2 = { boot_volume_gb = 50 }
      micro3 = { boot_volume_gb = 50 }
    }
  }

  expect_failures = [var.amd_micro_instances]
}

run "rejects_combined_storage_over_two_hundred_gb" {
  command = plan

  variables {
    compute_instances = {
      vm1 = {
        assign_public_ip = true
        boot_volume_gb   = 100
        memory_gb        = 24
        ocpus            = 4
        subnet_role      = "public"
      }
    }

    amd_micro_instances = {
      micro1 = { boot_volume_gb = 60 }
      micro2 = { boot_volume_gb = 60 }
    }
  }

  expect_failures = [var.amd_micro_instances]
}

run "rejects_amd_micro_instances_in_different_ads" {
  command = plan

  variables {
    compute_instances = {
      vm1 = {
        assign_public_ip = true
        boot_volume_gb   = 100
        memory_gb        = 24
        ocpus            = 4
        subnet_role      = "public"
      }
    }

    amd_micro_instances = {
      micro1 = {
        boot_volume_gb      = 50
        availability_domain = "kIdk:PHX-AD-1"
      }
      micro2 = {
        boot_volume_gb      = 50
        availability_domain = "kIdk:PHX-AD-2"
      }
    }
  }

  expect_failures = [var.amd_micro_instances]
}

run "rejects_private_subnet_outside_vcn" {
  command = plan

  variables {
    private_subnet_cidr = "10.1.2.0/24"
  }

  expect_failures = [oci_core_subnet.private]
}

run "rejects_overlapping_subnets" {
  command = plan

  variables {
    private_subnet_cidr = "10.0.1.128/25"
    public_subnet_cidr  = "10.0.1.0/24"
  }

  expect_failures = [oci_core_subnet.private]
}

run "rejects_postgresql_memory_below_sixteen_gb_per_ocpu" {
  command = plan

  variables {
    features = {
      postgresql = true
    }

    postgresql_instance_memory_size_in_gbs = 16
    postgresql_instance_ocpu_count         = 2
  }

  expect_failures = [var.postgresql_instance_memory_size_in_gbs]
}
