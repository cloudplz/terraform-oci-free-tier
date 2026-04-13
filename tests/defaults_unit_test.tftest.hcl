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
          name = "kIdk:PHX-AD-1"
        },
        {
          name = "kIdk:PHX-AD-2"
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
          region_key     = "PHX"
          region_name    = "us-phoenix-1"
          status         = "READY"
        }
      ]
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

run "default_fleet_uses_three_instances" {
  command = plan

  assert {
    condition     = length(oci_core_instance.vm) == 3
    error_message = "The default profile should create exactly three compute instances."
  }
}

run "default_fleet_consumes_full_a1_quota" {
  command = plan

  assert {
    condition     = sum([for instance in values(oci_core_instance.vm) : instance.shape_config[0].ocpus]) == 4
    error_message = "The default fleet should consume 4 OCPUs total."
  }

  assert {
    condition     = sum([for instance in values(oci_core_instance.vm) : instance.shape_config[0].memory_in_gbs]) == 24
    error_message = "The default fleet should consume 24 GB of memory total."
  }

  assert {
    condition     = sum([for instance in values(oci_core_instance.vm) : instance.source_details[0].boot_volume_size_in_gbs]) == 200
    error_message = "The default fleet should consume 200 GB of boot volume storage total."
  }
}

run "no_amd_micro_instances_by_default" {
  command = plan

  assert {
    condition     = length(oci_core_instance.micro) == 0
    error_message = "No AMD Micro instances should be created by default."
  }
}

run "default_free_features_enabled" {
  command = plan

  assert {
    condition     = length(oci_load_balancer_load_balancer.main) == 1
    error_message = "Load balancer should be created by default."
  }

  assert {
    condition     = length(oci_objectstorage_bucket.main) == 1
    error_message = "Object Storage should be created by default."
  }

  assert {
    condition     = length(oci_network_load_balancer_network_load_balancer.main) == 1
    error_message = "Network Load Balancer should be created by default."
  }

  assert {
    condition     = length(oci_mysql_mysql_db_system.main) == 1
    error_message = "MySQL DB System should be created by default."
  }

  assert {
    condition     = length(oci_core_volume_backup_policy_assignment.a1_boot) == 0
    error_message = "Boot volume backups should NOT be created by default (risk of exceeding 5-backup free limit)."
  }

  assert {
    condition     = length(oci_kms_vault.main) == 1
    error_message = "Vault should be created by default (MySQL is on, vault is on)."
  }

  assert {
    condition     = length(oci_kms_key.secrets) == 1
    error_message = "Secrets encryption key should be created when vault is enabled."
  }

  assert {
    condition     = length(oci_vault_secret.mysql_admin_password) == 1
    error_message = "MySQL admin password should be stored in Vault by default."
  }

  assert {
    condition     = length(oci_vault_secret.postgresql_admin_password) == 0
    error_message = "PostgreSQL secret should not be created when PostgreSQL is disabled."
  }
}

run "features_can_be_selectively_disabled" {
  command = plan

  variables {
    features = {
      mysql                 = false
      load_balancer         = false
      network_load_balancer = false
      object_storage        = false
      boot_volume_backup    = false
    }
  }

  assert {
    condition     = length(oci_load_balancer_load_balancer.main) == 0
    error_message = "Load balancer should be disabled when feature is false."
  }

  assert {
    condition     = length(oci_objectstorage_bucket.main) == 0
    error_message = "Object Storage should be disabled when feature is false."
  }

  assert {
    condition     = length(oci_network_load_balancer_network_load_balancer.main) == 0
    error_message = "Network Load Balancer should be disabled when feature is false."
  }

  assert {
    condition     = length(oci_mysql_mysql_db_system.main) == 0
    error_message = "MySQL DB System should be disabled when feature is false."
  }

  assert {
    condition     = length(oci_kms_vault.main) == 0
    error_message = "Vault should not be created when no database features are enabled."
  }
}

run "vault_disabled_skips_vault_resources" {
  command = plan

  variables {
    features = {
      vault = false
    }
  }

  assert {
    condition     = length(oci_kms_vault.main) == 0
    error_message = "Vault should not be created when features.vault is false."
  }

  assert {
    condition     = length(oci_vault_secret.mysql_admin_password) == 0
    error_message = "MySQL secret should not be created when vault is disabled."
  }

  assert {
    condition     = length(oci_mysql_mysql_db_system.main) == 1
    error_message = "MySQL DB System should still be created even when vault is off."
  }
}

run "vault_stores_postgresql_password_when_both_enabled" {
  command = plan

  variables {
    features = {
      postgresql = true
    }
  }

  assert {
    condition     = length(oci_vault_secret.mysql_admin_password) == 1
    error_message = "MySQL secret should be in Vault when vault and mysql are enabled."
  }

  assert {
    condition     = length(oci_vault_secret.postgresql_admin_password) == 1
    error_message = "PostgreSQL secret should be in Vault when vault and postgresql are enabled."
  }
}

run "no_nat_gateway_when_all_instances_public" {
  command = plan

  assert {
    condition     = length(oci_core_nat_gateway.main) == 0
    error_message = "NAT gateway should not be created when all instances are in the public subnet."
  }
}

run "nat_gateway_created_for_private_instances" {
  command = plan

  variables {
    compute_instances = {
      vm1 = {
        assign_public_ip = false
        boot_volume_gb   = 100
        memory_gb        = 12
        ocpus            = 2
        subnet_role      = "private"
      }
      vm2 = {
        assign_public_ip = true
        boot_volume_gb   = 100
        memory_gb        = 12
        ocpus            = 2
        subnet_role      = "public"
      }
    }
  }

  assert {
    condition     = length(oci_core_nat_gateway.main) == 1
    error_message = "NAT gateway should be created when any instance uses the private subnet."
  }
}

run "public_instances_get_public_ips_by_default" {
  command = plan

  assert {
    condition = alltrue([
      for instance in values(oci_core_instance.vm) : instance.create_vnic_details[0].assign_public_ip
    ])
    error_message = "The default compute instances should request public IPs."
  }
}

run "instance_availability_domain_overrides_take_precedence" {
  command = plan

  variables {
    availability_domain = "kIdk:PHX-AD-2"

    compute_instances = {
      vm1 = {
        assign_public_ip    = true
        availability_domain = "kIdk:PHX-AD-1"
        boot_volume_gb      = 50
        memory_gb           = 6
        ocpus               = 1
        subnet_role         = "public"
      }
      vm2 = {
        assign_public_ip = true
        boot_volume_gb   = 50
        memory_gb        = 6
        ocpus            = 1
        subnet_role      = "public"
      }
    }
  }

  assert {
    condition     = oci_core_instance.vm["vm1"].availability_domain == "kIdk:PHX-AD-1"
    error_message = "A per-instance availability domain should override the module default."
  }

  assert {
    condition     = oci_core_instance.vm["vm2"].availability_domain == "kIdk:PHX-AD-2"
    error_message = "Instances without an override should use the module default availability domain."
  }
}

run "default_fleet_spreads_across_availability_domains" {
  command = plan

  assert {
    condition     = oci_core_instance.vm["vm1"].availability_domain == "kIdk:PHX-AD-1"
    error_message = "vm1 (index 0) should be placed in the first AD."
  }

  assert {
    condition     = oci_core_instance.vm["vm2"].availability_domain == "kIdk:PHX-AD-2"
    error_message = "vm2 (index 1) should be placed in the second AD."
  }

  assert {
    condition     = oci_core_instance.vm["vm3"].availability_domain == "kIdk:PHX-AD-1"
    error_message = "vm3 (index 2) should wrap back to the first AD."
  }
}

run "load_balancer_registers_all_backends_by_default" {
  command = plan

  assert {
    condition     = length(oci_load_balancer_backend.main) == 3
    error_message = "The load balancer should register all 3 default instances as backends."
  }
}

run "load_balancer_respects_explicit_backend_keys" {
  command = plan

  variables {
    load_balancer_backend_instance_keys = ["vm1", "vm3"]
    load_balancer_backend_port          = 8080
    load_balancer_listener_port         = 8080
  }

  assert {
    condition     = length(oci_load_balancer_backend.main) == 2
    error_message = "The load balancer should only register the specified backend instances."
  }

  assert {
    condition     = oci_load_balancer_listener.http[0].port == 8080
    error_message = "The load balancer listener should use the configured listener port."
  }
}

run "icmp_rules_are_always_created" {
  command = plan

  assert {
    condition     = oci_core_network_security_group_security_rule.compute_ingress_icmp.protocol == "1"
    error_message = "ICMP path MTU discovery rule should always be created."
  }

  assert {
    condition     = oci_core_network_security_group_security_rule.compute_ingress_icmp_echo.protocol == "1"
    error_message = "ICMP echo request rule should always be created."
  }
}

run "mysql_uses_free_shape" {
  command = plan

  assert {
    condition     = oci_mysql_mysql_db_system.main[0].shape_name == "MySQL.Free"
    error_message = "MySQL DB System should use the MySQL.Free shape."
  }

  assert {
    condition     = oci_mysql_mysql_db_system.main[0].data_storage_size_in_gb == 50
    error_message = "MySQL DB System should use 50 GB storage."
  }

  assert {
    condition     = oci_mysql_mysql_db_system.main[0].is_highly_available == false
    error_message = "MySQL DB System should not use high availability (not available on free tier)."
  }
}

run "postgresql_not_created_by_default" {
  command = plan

  assert {
    condition     = length(oci_psql_db_system.main) == 0
    error_message = "PostgreSQL should not be created by default (it is a paid resource)."
  }
}

run "postgresql_created_when_enabled" {
  command = plan

  variables {
    features = {
      postgresql = true
    }
  }

  assert {
    condition     = length(oci_psql_db_system.main) == 1
    error_message = "PostgreSQL should be created when features.postgresql is true."
  }

  assert {
    condition     = oci_psql_db_system.main[0].instance_count == 1
    error_message = "PostgreSQL should use a single node."
  }
}

run "budget_not_created_without_tenancy_id" {
  command = plan

  assert {
    condition     = length(oci_budget_budget.free_tier) == 0
    error_message = "Budget should not be created when tenancy_id is null."
  }
}

run "budget_created_when_tenancy_id_set" {
  command = plan

  variables {
    tenancy_id = "ocid1.tenancy.oc1..exampleuniqueID"
  }

  assert {
    condition     = length(oci_budget_budget.free_tier) == 1
    error_message = "Budget should be created when tenancy_id is set."
  }

  assert {
    condition     = oci_budget_budget.free_tier[0].amount == 1
    error_message = "Budget amount should default to $1."
  }

  assert {
    condition     = oci_budget_budget.free_tier[0].reset_period == "MONTHLY"
    error_message = "Budget should reset monthly."
  }
}

run "budget_alert_requires_email" {
  command = plan

  variables {
    tenancy_id = "ocid1.tenancy.oc1..exampleuniqueID"
  }

  assert {
    condition     = length(oci_budget_alert_rule.any_spending) == 0
    error_message = "Budget alert rule should not be created without budget_alert_email."
  }
}

run "budget_alert_created_with_email" {
  command = plan

  variables {
    tenancy_id         = "ocid1.tenancy.oc1..exampleuniqueID"
    budget_alert_email = "ops@example.com"
  }

  assert {
    condition     = length(oci_budget_alert_rule.any_spending) == 1
    error_message = "Budget alert rule should be created when both tenancy_id and budget_alert_email are set."
  }

  assert {
    condition     = oci_budget_alert_rule.any_spending[0].threshold == 100
    error_message = "Alert should trigger at 100% of budget."
  }

  assert {
    condition     = oci_budget_alert_rule.any_spending[0].type == "ACTUAL"
    error_message = "Alert should use ACTUAL spending type."
  }
}
