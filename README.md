# Terraform OCI Free Tier

[![CI](https://img.shields.io/github/actions/workflow/status/cloudplz/terraform-oci-free-tier/ci.yml?branch=main&label=CI)](https://github.com/cloudplz/terraform-oci-free-tier/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Provision a curated Oracle Cloud Infrastructure Always Free starter environment in a single
`terraform apply`.

A single `terraform apply` with the three required variables creates a starter stack covering
the most commonly used Always Free services: 3 Arm VMs, a MySQL DB System, Flexible Load
Balancer, Network Load Balancer, and an Object Storage bucket. This module does **not** cover
every OCI Always Free service -- see [Always Free Coverage](#always-free-coverage) for the full
gap list.

The default compute fleet uses the full Always Free A1 pooled limit:

| Instance | OCPUs | RAM | Boot Volume |
|----------|-------|-----|-------------|
| `vm1` | 1 | 6 GB | 50 GB |
| `vm2` | 1 | 6 GB | 50 GB |
| `vm3` | 2 | 12 GB | 100 GB |
| **Total** | **4** | **24 GB** | **200 GB** |

## Prerequisites

> [!CAUTION]
> **Home region is critical.** Always Free allowances apply **only** in the tenancy home region.
> Deploying outside the home region incurs standard pay-as-you-go charges for every resource.
> Set `tenancy_id` so the module can detect non-home-region deployments. Without it, this safety
> check is skipped.

> [!IMPORTANT]
> Always Free compute, block volumes, MySQL, and Object Storage allowances are tied to your
> tenancy's home region. Configure the OCI provider for the home region before using this module.

> [!IMPORTANT]
> OCI Ampere A1 capacity is sometimes unavailable in a given availability domain. If OCI returns an
> out-of-capacity error, try a different availability domain or wait and retry.

The module assumes OCI provider authentication is already configured through the OCI CLI config,
environment variables, or another supported provider auth mechanism.

## Required IAM Permissions

If you are not applying this module as a tenancy administrator, the Terraform identity needs enough
permission to manage networking, compute, and boot volumes in the target compartment.

For a practical least-privilege starting point, grant these compartment-scoped policies to the group
or user running Terraform:

```text
Allow group <group-name> to manage virtual-network-family in compartment <compartment-name>
Allow group <group-name> to manage instance-family in compartment <compartment-name>
Allow group <group-name> to manage volume-family in compartment <compartment-name>
```

These policies are also needed for features that are enabled by default. Disable the corresponding
feature flag to skip them:

```text
Allow group <group-name> to manage object-family in compartment <compartment-name>
Allow group <group-name> to manage load-balancers in compartment <compartment-name>
Allow group <group-name> to manage mysql-family in compartment <compartment-name>
```

The Vault (enabled by default) requires:

```text
Allow group <group-name> to manage vaults in compartment <compartment-name>
Allow group <group-name> to manage keys in compartment <compartment-name>
Allow group <group-name> to manage secret-family in compartment <compartment-name>
```

If you enable `features.postgresql` (disabled by default, **paid resource**):

```text
Allow group <group-name> to manage postgresql-family in compartment <compartment-name>
```

If you set `tenancy_id` to enable the budget safety net, this **tenancy-level** policy is required:

```text
Allow group <group-name> to manage usage-budgets in tenancy
```

If your tenancy uses tighter guard rails such as custom images, Vault-managed encryption keys, or
cross-compartment networking, you may need extra OCI policies beyond the starter set above.

## Usage

### Minimal

```hcl
provider "oci" {
  region = var.region
}

module "free_tier" {
  source = "cloudplz/free-tier/oci"

  name           = "homelab"
  compartment_id = var.compartment_id
  ssh_public_key = file("~/.ssh/id_ed25519.pub")

  ssh_ingress_cidr = "203.0.113.42/32"
}
```

### Disable Specific Features

Most Always Free features are enabled by default. Turn off what you do not need:

```hcl
module "free_tier" {
  source = "cloudplz/free-tier/oci"

  name           = "homelab"
  compartment_id = var.compartment_id
  ssh_public_key = file("~/.ssh/id_ed25519.pub")

  features = {
    mysql         = false
    load_balancer = false
  }
}
```

### Use An Explicit Image OCID

```hcl
module "free_tier" {
  source = "cloudplz/free-tier/oci"

  name              = "homelab"
  compartment_id    = var.compartment_id
  image_id_override = "ocid1.image.oc1.phx.exampleuniqueID"
  ssh_public_key    = file("~/.ssh/id_ed25519.pub")
}
```

### Availability Domain Placement

By default, A1 instances are round-robin distributed across every availability domain in the
region. In a 3-AD region the default 3-VM fleet spreads as: vm1 → AD-1, vm2 → AD-2,
vm3 → AD-3. This improves availability and helps work around A1 capacity shortages.

To pin the whole fleet to a single AD, set `availability_domain`:

```hcl
module "free_tier" {
  source = "cloudplz/free-tier/oci"

  name                = "homelab"
  compartment_id      = var.compartment_id
  ssh_public_key      = file("~/.ssh/id_ed25519.pub")
  availability_domain = "kIdk:PHX-AD-2"
}
```

You can also set per-instance overrides via `compute_instances[*].availability_domain`.

See [examples/complete](examples/complete) for a ready-to-apply configuration.

## Default Resources Created

A single `terraform apply` with the three required variables (`name`, `compartment_id`,
`ssh_public_key`) creates the resources below. Each maps to an
[OCI Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
category. Total: ~30 OCI resources, **$0/month** when deployed in the home region.

### Infrastructure

| Resource | Terraform Address | Always Free Guard Rail |
|---|---|---|
| VCN (10.0.0.0/16) | `oci_core_vcn.main` | 2 VCNs per tenancy; module creates 1 |
| Public subnet + route table + internet gateway | `oci_core_subnet.public`, `oci_core_route_table.public`, `oci_core_internet_gateway.main` | Part of VCN |
| Private subnet + route table | `oci_core_subnet.private`, `oci_core_route_table.private` | Part of VCN |
| Compute NSG (ICMP + optional SSH) | `oci_core_network_security_group.compute` | Part of VCN |
| 3 Arm VM instances (VM.Standard.A1.Flex) | `oci_core_instance.vm["vm1"]` through `vm3` | 4 OCPUs, 24 GB, 200 GB validated |
| Object Storage bucket | `oci_objectstorage_bucket.main` | 20 GB total across all tiers -- **monitor usage** |

### Database

| Resource | Terraform Address | Always Free Guard Rail |
|---|---|---|
| MySQL DB System (private subnet) | `oci_mysql_mysql_db_system.main` | `MySQL.Free` shape -- **charges impossible** |
| MySQL security list (ports 3306, 33060) | `oci_core_security_list.mysql` | Part of VCN |

### Networking

| Resource | Terraform Address | Always Free Guard Rail |
|---|---|---|
| Flexible Load Balancer (10 Mbps) | `oci_load_balancer_load_balancer.main` | Hardcoded 10/10 Mbps -- **charges impossible** |
| LB backend set + backends + listener | `oci_load_balancer_backend_set.main`, `oci_load_balancer_backend.main`, `oci_load_balancer_listener.http` | Part of LB |
| LB NSG | `oci_core_network_security_group.load_balancer` | Part of VCN |
| Network Load Balancer | `oci_network_load_balancer_network_load_balancer.main` | 1 NLB free |
| NLB backend set + backends + listener | `oci_network_load_balancer_backend_set.main`, `oci_network_load_balancer_backend.main`, `oci_network_load_balancer_listener.main` | Part of NLB |
| NLB NSG | `oci_core_network_security_group.network_load_balancer` | Part of VCN |

### Security

| Resource | Terraform Address | Always Free Guard Rail |
|---|---|---|
| Vault (software-protected) | `oci_kms_vault.main` | 150 secrets, 20 key versions per tenancy |
| Master encryption key (AES-256, SOFTWARE) | `oci_kms_key.secrets` | Part of Vault |
| MySQL admin password secret | `oci_vault_secret.mysql_admin_password` | When `features.mysql` is true |
| PostgreSQL admin password secret | `oci_vault_secret.postgresql_admin_password` | When `features.postgresql` is true |

### Governance (when `tenancy_id` is set)

| Resource | Terraform Address | Always Free Guard Rail |
|---|---|---|
| $1/month budget | `oci_budget_budget.free_tier` | Budgets are free |
| Alert rule (fires when spending reaches budget amount) | `oci_budget_alert_rule.any_spending` | Requires `budget_alert_email` |

### Not Created by Default

| Resource | How to Enable | Cost |
|---|---|---|
| Boot volume backup policy (bronze) | Set `features.boot_volume_backup = true` | Always Free up to 5 copies -- **charges likely** with default fleet |
| AMD Micro instances (VM.Standard.E2.1.Micro) | Set `amd_micro_instances` map | Always Free (must be in a single AD in multi-AD regions) |
| NAT gateway | Auto-created when any instance uses `subnet_role = "private"` | Always Free |
| PostgreSQL DB system | Set `features.postgresql = true` | **PAID** -- compute + storage charges apply |

The Vault is created automatically when any database feature is enabled. Set `features.vault = false` to
skip it. Every feature-flagged resource can be individually disabled by setting `features.<name> = false`.

## Always Free Limits Reference

The following OCI Always Free limits are enforced or relevant to this module. All allowances apply
**only in the tenancy home region**. Set `tenancy_id` to enable the home-region check.

| Resource | Always Free Allowance | Module Guard Rail | Charge Risk |
|---|---|---|---|
| A1 Compute (Arm) | 4 OCPUs, 24 GB RAM total | Validated on `compute_instances` | None -- shape is free-tier only |
| AMD Micro Compute | 2 instances, 1/8 OCPU + 1 GB each, same AD | Validated on `amd_micro_instances` | None -- shape is free-tier only |
| Boot + Block Volume | 200 GB combined | Validated across both instance types | None -- enforced by validation |
| Boot Volume Backups | 5 backup copies total | Defaults to **off**; opt in with `features.boot_volume_backup = true` | **Yes** -- bronze policy may accumulate > 5 copies |
| Object Storage | 20 GB total across Standard + IA + Archive tiers, 50K API requests/month (per account) | **Not enforced** | **Yes** -- exceeding either limit incurs charges |
| MySQL DB System | 1 DB system, 50 GB, 8 GB RAM | `shape_name = "MySQL.Free"` | None -- shape is free-tier only |
| PostgreSQL | Not Always Free | Disabled by default (`features.postgresql = false`) | **Yes** -- compute and storage charges apply when enabled |
| Vault / Key Management | 150 secrets, 20 HSM key versions | SOFTWARE protection mode | None -- within Always Free limits |
| Flexible Load Balancer | 1 at 10 Mbps | Hardcoded to 10 Mbps | None -- bandwidth is the free maximum |
| Network Load Balancer | 1 | Module creates at most 1 | None -- 1 instance is free |
| VCN + Networking | 2 VCNs, all components | Module creates 1 VCN | None -- networking is free |
| Outbound Data Transfer | 10 TB/month | **Not enforced** | **Yes** -- exceeding 10 TB incurs charges |

## Cost And Quota Guard Rails

The module enforces these constraints with variable validation:

- no more than 4 total A1 OCPUs
- no more than 24 total A1 memory GB
- no more than 200 combined boot volume GB (A1 + AMD Micro)
- no more than 4 A1 instances and 2 AMD Micro instances
- all AMD Micro instances must use the same availability domain (Oracle requirement)
- no boot volume smaller than 50 GB
- load balancer hardcoded to the Always Free 10 Mbps flexible shape
- MySQL DB System always created with `shape_name = "MySQL.Free"` (50 GB, no HA)
- boot volume backups disabled by default to avoid exceeding the 5-backup free limit
- Vault uses SOFTWARE protection mode only (Always Free)
- PostgreSQL disabled by default to prevent unexpected charges

### Resources That Cannot Incur Charges

These resources are locked to free-tier shapes or flags. Charges are structurally impossible
regardless of usage, as long as you deploy in the home region:

- **MySQL DB System**: `MySQL.Free` shape -- exclusively free-tier, no paid upgrade path without changing shape
- **Flexible Load Balancer**: hardcoded to 10/10 Mbps -- the free-tier maximum bandwidth
- **Network Load Balancer**: 1 instance is free with no bandwidth constraint
- **Compute instances**: free-tier shapes (`VM.Standard.A1.Flex`, `VM.Standard.E2.1.Micro`) within validated limits
- **Vault / Key Management**: software-protected vault and keys with up to 150 secrets -- well within Always Free limits
- **Networking**: VCN, subnets, gateways, route tables, NSGs are all free

### Resources That Can Incur Charges

These resources have usage-based limits that the module does not enforce:

- **Object Storage**: 20 GB total across Standard, Infrequent Access, and Archive tiers combined, plus 50,000 API requests/month per account. The module creates a Standard tier bucket. Charges apply if you exceed either limit.
- **Boot Volume Backups** (off by default): free for up to 5 backup copies total across all volumes. The "bronze" policy creates monthly backups with 12-month retention. The default 3-VM fleet exceeds the free limit within 2 months.
- **Outbound Data Transfer**: free up to 10 TB/month. Charges apply above this threshold.
- **PostgreSQL** (disabled by default): OCI Database with PostgreSQL is not part of the Always Free tier. When `features.postgresql = true`, hourly compute and storage charges apply immediately.
- **All resources outside the home region**: Always Free allowances only apply in the tenancy home region. Set `tenancy_id` to enable the built-in home-region check.

## Known OCI Caveats

- Idle Always Free compute instances can be reclaimed by Oracle.
- The default 3-VM profile leaves no A1 or boot volume headroom for a fourth instance.
- The load balancer is provisioned with the Always Free 10 Mbps flexible shape.
- Load balancer backend instances still need an application listening on the configured backend port.
- Auto-generated MySQL and PostgreSQL admin passwords are stored in Terraform state (the OCI provider
  does not yet support write-only password attributes). When `features.vault = true` (default), the
  module also writes each password to an
  [OCI Vault](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm)
  secret (up to 150 secrets are Always Free). Downstream systems can read passwords from Vault
  using the secret OCID output instead of the raw password.
- If OCI image lookup returns no results in your tenancy or region, set `image_id_override` to a
  specific platform image OCID.
- The MySQL DB System is placed in the private subnet for security. Compute instances in
  the VCN can connect on ports 3306 (classic) and 33060 (X Protocol). The separate Always Free
  HeatWave cluster (`HeatWave.Free` shape) is not yet implemented by this module.
- The PostgreSQL DB system (when enabled) is also placed in the private subnet, accessible on port
  5432 from within the VCN.

## Troubleshooting

- `Out of host capacity` when creating `VM.Standard.A1.Flex` instances usually means the selected
  availability domain is temporarily full. Retry later or set `availability_domain` to a different
  AD in your home region. If only part of the fleet is failing, spread instances across multiple
  ADs with per-instance `compute_instances[*].availability_domain` overrides.
- `No OCI platform image matched...` means the tenancy or region did not return a compatible
  platform image for the selected operating system filters. Set `image_id_override` to an explicit
  image OCID.
- `NotAuthorizedOrNotFound` or similar API authorization failures usually mean the Terraform
  identity is missing one of the IAM policy families listed above.
- Unexpected charges usually mean the provider region is not set to the tenancy home region, which
  is where Oracle applies most Always Free allowances. Set `tenancy_id` to enable the built-in
  home-region check.

## Always Free Coverage

How this module maps to the
[OCI Always Free catalog](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
as of April 2025.

### Implemented

| Service | Module Resource | Notes |
|---|---|---|
| Compute -- Ampere A1 Flex | `oci_core_instance.vm` | 4 OCPUs, 24 GB RAM, 200 GB boot volume validated |
| Compute -- AMD Micro | `oci_core_instance.micro` | Up to 2 instances, same-AD enforced |
| Block Volume (boot volumes) | Validated via `compute_instances` / `amd_micro_instances` | 200 GB combined limit |
| Boot Volume Backups | `oci_core_volume_backup_policy_assignment` | Off by default; 5-copy free limit |
| Object Storage | `oci_objectstorage_bucket.main` | 1 Standard bucket; 20 GB total across tiers |
| MySQL DB System | `oci_mysql_mysql_db_system.main` | `MySQL.Free` shape -- charges impossible |
| Flexible Load Balancer | `oci_load_balancer_load_balancer.main` | 10 Mbps hardcoded |
| Network Load Balancer | `oci_network_load_balancer_network_load_balancer.main` | 1 instance |
| VCN + subnets + gateways + NSGs | `oci_core_vcn.main` and related | 1 VCN of 2 allowed |
| Budget + Alert Rule | `oci_budget_budget.free_tier` | When `tenancy_id` is set |
| OCI Vault / Key Management | `oci_kms_vault.main`, `oci_kms_key.secrets`, `oci_vault_secret.*` | SOFTWARE keys; DB passwords stored as secrets |

### Not Yet Implemented (Always Free Eligible)

| Service | Always Free Allowance |
|---|---|
| MySQL HeatWave cluster | `HeatWave.Free` shape (separate from the DB system) |
| Certificates | 5 private CAs, 150 certificates |
| NoSQL Database | 133M read units, 133M write units, 3 tables at 25 GB each |
| Bastion | Free for all OCI accounts |
| VCN Flow Logs | 10 GB/month |
| Site-to-Site VPN | 50 IPSec connections |
| Email Delivery | 3,000 emails/month |
| Monitoring | 500M ingestion datapoints, 1B retrieval datapoints |
| Notifications | 1M HTTPS deliveries, 1,000 email deliveries/month |
| Logging | Included with tenancy |
| Connector Hub | 2 service connectors |
| APM | 1,000 tracing events/hour, 10 synthetic monitor runs/hour |
| Console Dashboards | 100 per tenancy |

### Excluded by Design

| Service | Reason |
|---|---|
| Oracle Autonomous Database | Excluded per user request |

### Opt-in Paid Resources

| Service | How to Enable | Default |
|---|---|---|
| PostgreSQL DB System | `features.postgresql = true` | `false` -- hourly charges apply |

## Disclaimer

This module is designed to stay inside OCI Always Free limits, but **you are responsible for
monitoring your own tenancy usage and charges**. Oracle can change Always Free terms, quotas, or
regional availability at any time.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11, < 2.0.0 |
| <a name="requirement_oci"></a> [oci](#requirement\_oci) | ~> 8.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_oci"></a> [oci](#provider\_oci) | 8.9.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |

## Resources

| Name | Type |
|------|------|
| [oci_budget_alert_rule.any_spending](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/budget_alert_rule) | resource |
| [oci_budget_budget.free_tier](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/budget_budget) | resource |
| [oci_core_instance.micro](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance) | resource |
| [oci_core_instance.vm](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_instance) | resource |
| [oci_core_internet_gateway.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_internet_gateway) | resource |
| [oci_core_nat_gateway.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_nat_gateway) | resource |
| [oci_core_network_security_group.compute](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group) | resource |
| [oci_core_network_security_group.load_balancer](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group) | resource |
| [oci_core_network_security_group.network_load_balancer](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group) | resource |
| [oci_core_network_security_group_security_rule.compute_egress_all](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.compute_ingress_icmp](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.compute_ingress_icmp_echo](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.compute_ingress_load_balancer](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.compute_ingress_nlb](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.compute_ingress_ssh](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.load_balancer_egress_backend](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.load_balancer_ingress_listener](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.nlb_egress_backend](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_network_security_group_security_rule.nlb_ingress_listener](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule) | resource |
| [oci_core_route_table.private](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_route_table) | resource |
| [oci_core_route_table.public](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_route_table) | resource |
| [oci_core_security_list.mysql](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_security_list) | resource |
| [oci_core_security_list.postgresql](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_security_list) | resource |
| [oci_core_subnet.private](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_subnet) | resource |
| [oci_core_subnet.public](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_subnet) | resource |
| [oci_core_vcn.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_vcn) | resource |
| [oci_core_volume_backup_policy_assignment.a1_boot](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_volume_backup_policy_assignment) | resource |
| [oci_core_volume_backup_policy_assignment.micro_boot](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_volume_backup_policy_assignment) | resource |
| [oci_kms_key.secrets](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/kms_key) | resource |
| [oci_kms_vault.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/kms_vault) | resource |
| [oci_load_balancer_backend.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_backend) | resource |
| [oci_load_balancer_backend_set.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_backend_set) | resource |
| [oci_load_balancer_listener.http](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_listener) | resource |
| [oci_load_balancer_load_balancer.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_load_balancer) | resource |
| [oci_mysql_mysql_db_system.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/mysql_mysql_db_system) | resource |
| [oci_network_load_balancer_backend.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/network_load_balancer_backend) | resource |
| [oci_network_load_balancer_backend_set.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/network_load_balancer_backend_set) | resource |
| [oci_network_load_balancer_listener.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/network_load_balancer_listener) | resource |
| [oci_network_load_balancer_network_load_balancer.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/network_load_balancer_network_load_balancer) | resource |
| [oci_objectstorage_bucket.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/objectstorage_bucket) | resource |
| [oci_psql_db_system.main](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/psql_db_system) | resource |
| [oci_vault_secret.mysql_admin_password](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/vault_secret) | resource |
| [oci_vault_secret.postgresql_admin_password](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/vault_secret) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.mysql_admin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.postgresql_admin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_compartment_id"></a> [compartment\_id](#input\_compartment\_id) | OCID of the compartment where all resources will be created. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix applied to created resources. Keep it short and lowercase. | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | SSH public key added to each compute instance via cloud-init metadata. | `string` | n/a | yes |
| <a name="input_amd_micro_instances"></a> [amd\_micro\_instances](#input\_amd\_micro\_instances) | Map of Always Free AMD Micro instances to create (VM.Standard.E2.1.Micro). Each instance has a fixed 1/8 OCPU and 1 GB RAM. Boot volumes share the 200 GB Always Free budget with A1 instances. | <pre>map(object({<br/>    assign_public_ip    = optional(bool, true)<br/>    availability_domain = optional(string)<br/>    boot_volume_gb      = optional(number, 50)<br/>    subnet_role         = optional(string, "public")<br/>  }))</pre> | `{}` | no |
| <a name="input_availability_domain"></a> [availability\_domain](#input\_availability\_domain) | Default availability domain for compute instances. Set to null to use the first AD returned by OCI unless an instance overrides it. | `string` | `null` | no |
| <a name="input_budget_alert_email"></a> [budget\_alert\_email](#input\_budget\_alert\_email) | Email address for the budget alert rule. When set together with tenancy\_id and features.budget, the module creates a $1 monthly budget with an alert that fires when spending reaches the budget amount. | `string` | `null` | no |
| <a name="input_budget_amount"></a> [budget\_amount](#input\_budget\_amount) | Monthly budget amount in the tenancy currency. Only used when features.budget is true and tenancy\_id is set. | `number` | `1` | no |
| <a name="input_compute_instances"></a> [compute\_instances](#input\_compute\_instances) | Map of Always Free A1 instances to create. The default profile exactly consumes 4 OCPUs, 24 GB RAM, and 200 GB boot volume storage. | <pre>map(object({<br/>    assign_public_ip    = optional(bool, true)<br/>    availability_domain = optional(string)<br/>    boot_volume_gb      = number<br/>    memory_gb           = number<br/>    ocpus               = number<br/>    subnet_role         = optional(string, "public")<br/>    user_data           = optional(string)<br/>  }))</pre> | <pre>{<br/>  "vm1": {<br/>    "assign_public_ip": true,<br/>    "boot_volume_gb": 50,<br/>    "memory_gb": 6,<br/>    "ocpus": 1,<br/>    "subnet_role": "public"<br/>  },<br/>  "vm2": {<br/>    "assign_public_ip": true,<br/>    "boot_volume_gb": 50,<br/>    "memory_gb": 6,<br/>    "ocpus": 1,<br/>    "subnet_role": "public"<br/>  },<br/>  "vm3": {<br/>    "assign_public_ip": true,<br/>    "boot_volume_gb": 100,<br/>    "memory_gb": 12,<br/>    "ocpus": 2,<br/>    "subnet_role": "public"<br/>  }<br/>}</pre> | no |
| <a name="input_defined_tags"></a> [defined\_tags](#input\_defined\_tags) | Defined tags applied to all supported OCI resources. | `map(string)` | `{}` | no |
| <a name="input_features"></a> [features](#input\_features) | Services to provision. Most Always Free services default to true. Boot volume backups and PostgreSQL default to false because they can incur charges with default settings. | <pre>object({<br/>    boot_volume_backup    = optional(bool, false)<br/>    budget                = optional(bool, true)<br/>    load_balancer         = optional(bool, true)<br/>    mysql                 = optional(bool, true)<br/>    network_load_balancer = optional(bool, true)<br/>    object_storage        = optional(bool, true)<br/>    postgresql            = optional(bool, false)<br/>    vault                 = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_freeform_tags"></a> [freeform\_tags](#input\_freeform\_tags) | Free-form tags applied to all supported OCI resources. | `map(string)` | `{}` | no |
| <a name="input_image_id_override"></a> [image\_id\_override](#input\_image\_id\_override) | Optional explicit OCI image OCID for the compute fleet. Use this if the platform image lookup does not return a match in your region or tenancy. | `string` | `null` | no |
| <a name="input_load_balancer_backend_instance_keys"></a> [load\_balancer\_backend\_instance\_keys](#input\_load\_balancer\_backend\_instance\_keys) | Set of compute instance keys to register as load balancer backends. Set to null to register all compute instances. | `set(string)` | `null` | no |
| <a name="input_load_balancer_backend_port"></a> [load\_balancer\_backend\_port](#input\_load\_balancer\_backend\_port) | Port the optional load balancer should use to reach its backend instance. | `number` | `80` | no |
| <a name="input_load_balancer_listener_port"></a> [load\_balancer\_listener\_port](#input\_load\_balancer\_listener\_port) | Port the optional load balancer should expose to clients. | `number` | `80` | no |
| <a name="input_mysql_admin_password"></a> [mysql\_admin\_password](#input\_mysql\_admin\_password) | Optional admin password for the MySQL DB system. Leave null to let Terraform generate one when features.mysql is true. | `string` | `null` | no |
| <a name="input_mysql_admin_username"></a> [mysql\_admin\_username](#input\_mysql\_admin\_username) | Admin username for the MySQL DB system. | `string` | `"admin"` | no |
| <a name="input_network_load_balancer_port"></a> [network\_load\_balancer\_port](#input\_network\_load\_balancer\_port) | Port for the optional network load balancer listener and backends. | `number` | `80` | no |
| <a name="input_object_storage_bucket_name"></a> [object\_storage\_bucket\_name](#input\_object\_storage\_bucket\_name) | Optional explicit bucket name. Leave null to let Terraform generate a unique one. | `string` | `null` | no |
| <a name="input_operating_system"></a> [operating\_system](#input\_operating\_system) | OCI platform image operating system for the compute fleet. | `string` | `"Ubuntu"` | no |
| <a name="input_operating_system_version"></a> [operating\_system\_version](#input\_operating\_system\_version) | Optional OCI platform image operating system version filter. Leave null to let OCI choose the newest image for the selected OS. | `string` | `null` | no |
| <a name="input_postgresql_admin_password"></a> [postgresql\_admin\_password](#input\_postgresql\_admin\_password) | Optional admin password for the PostgreSQL DB system. Leave null to let Terraform generate one when features.postgresql is true. | `string` | `null` | no |
| <a name="input_postgresql_admin_username"></a> [postgresql\_admin\_username](#input\_postgresql\_admin\_username) | Admin username for the PostgreSQL DB system. | `string` | `"pgadmin"` | no |
| <a name="input_postgresql_db_version"></a> [postgresql\_db\_version](#input\_postgresql\_db\_version) | PostgreSQL major version for the DB system. | `string` | `"16"` | no |
| <a name="input_postgresql_instance_memory_size_in_gbs"></a> [postgresql\_instance\_memory\_size\_in\_gbs](#input\_postgresql\_instance\_memory\_size\_in\_gbs) | Memory in GB for the PostgreSQL DB system. Minimum 16 GB per OCPU. | `number` | `16` | no |
| <a name="input_postgresql_instance_ocpu_count"></a> [postgresql\_instance\_ocpu\_count](#input\_postgresql\_instance\_ocpu\_count) | Number of OCPUs for the PostgreSQL DB system. Minimum 1. | `number` | `1` | no |
| <a name="input_postgresql_shape"></a> [postgresql\_shape](#input\_postgresql\_shape) | Shape name for the PostgreSQL DB system. Uses the flexible shape with OCPU/memory controlled by postgresql\_instance\_ocpu\_count and postgresql\_instance\_memory\_size\_in\_gbs. | `string` | `"PostgreSQL.VM.Standard.E5.Flex"` | no |
| <a name="input_private_subnet_cidr"></a> [private\_subnet\_cidr](#input\_private\_subnet\_cidr) | CIDR block for the private subnet. | `string` | `"10.0.2.0/24"` | no |
| <a name="input_public_subnet_cidr"></a> [public\_subnet\_cidr](#input\_public\_subnet\_cidr) | CIDR block for the public subnet. | `string` | `"10.0.1.0/24"` | no |
| <a name="input_ssh_ingress_cidr"></a> [ssh\_ingress\_cidr](#input\_ssh\_ingress\_cidr) | Optional CIDR allowed to SSH into the compute fleet. Set null to create no SSH ingress rule. | `string` | `null` | no |
| <a name="input_tenancy_id"></a> [tenancy\_id](#input\_tenancy\_id) | Optional tenancy OCID for home-region validation. When set, the module warns if resources are not being created in the tenancy home region where Always Free allowances apply. | `string` | `null` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | Optional cloud-init or shell script user data. The module base64-encodes it before sending it to OCI. | `string` | `null` | no |
| <a name="input_vcn_cidr"></a> [vcn\_cidr](#input\_vcn\_cidr) | CIDR block for the VCN. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_amd_micro_instances"></a> [amd\_micro\_instances](#output\_amd\_micro\_instances) | Map of AMD Micro instance details keyed by instance name, or an empty map when none are configured. |
| <a name="output_availability_domain"></a> [availability\_domain](#output\_availability\_domain) | Default availability domain used for compute instances without an explicit per-instance override. |
| <a name="output_budget_id"></a> [budget\_id](#output\_budget\_id) | OCID of the safety-net budget, or null when disabled or tenancy\_id is not set. |
| <a name="output_compute_instances"></a> [compute\_instances](#output\_compute\_instances) | Map of compute instance details keyed by instance name. |
| <a name="output_load_balancer_id"></a> [load\_balancer\_id](#output\_load\_balancer\_id) | OCID of the optional load balancer, or null when disabled. |
| <a name="output_load_balancer_ip_addresses"></a> [load\_balancer\_ip\_addresses](#output\_load\_balancer\_ip\_addresses) | IP addresses assigned to the optional load balancer, or an empty list when disabled. |
| <a name="output_mysql_admin_password"></a> [mysql\_admin\_password](#output\_mysql\_admin\_password) | MySQL admin password when features.mysql is enabled. |
| <a name="output_mysql_admin_password_secret_id"></a> [mysql\_admin\_password\_secret\_id](#output\_mysql\_admin\_password\_secret\_id) | OCID of the Vault secret containing the MySQL admin password, or null when vault or MySQL is disabled. |
| <a name="output_mysql_db_system_id"></a> [mysql\_db\_system\_id](#output\_mysql\_db\_system\_id) | OCID of the optional Always Free MySQL DB system, or null when disabled. |
| <a name="output_mysql_db_system_ip_address"></a> [mysql\_db\_system\_ip\_address](#output\_mysql\_db\_system\_ip\_address) | Private IP address of the MySQL DB system endpoint, or null when disabled. |
| <a name="output_network_load_balancer_id"></a> [network\_load\_balancer\_id](#output\_network\_load\_balancer\_id) | OCID of the optional network load balancer, or null when disabled. |
| <a name="output_network_load_balancer_ip_addresses"></a> [network\_load\_balancer\_ip\_addresses](#output\_network\_load\_balancer\_ip\_addresses) | IP addresses assigned to the optional network load balancer, or an empty list when disabled. |
| <a name="output_object_storage_bucket_name"></a> [object\_storage\_bucket\_name](#output\_object\_storage\_bucket\_name) | Name of the optional Object Storage bucket, or null when disabled. |
| <a name="output_object_storage_namespace"></a> [object\_storage\_namespace](#output\_object\_storage\_namespace) | Object Storage namespace for the tenancy. |
| <a name="output_postgresql_admin_password"></a> [postgresql\_admin\_password](#output\_postgresql\_admin\_password) | PostgreSQL admin password when features.postgresql is enabled. |
| <a name="output_postgresql_admin_password_secret_id"></a> [postgresql\_admin\_password\_secret\_id](#output\_postgresql\_admin\_password\_secret\_id) | OCID of the Vault secret containing the PostgreSQL admin password, or null when vault or PostgreSQL is disabled. |
| <a name="output_postgresql_db_system_id"></a> [postgresql\_db\_system\_id](#output\_postgresql\_db\_system\_id) | OCID of the optional PostgreSQL DB system, or null when disabled. |
| <a name="output_postgresql_db_system_ip_address"></a> [postgresql\_db\_system\_ip\_address](#output\_postgresql\_db\_system\_ip\_address) | Private IP address of the PostgreSQL DB system primary endpoint, or null when disabled. |
| <a name="output_private_subnet_id"></a> [private\_subnet\_id](#output\_private\_subnet\_id) | OCID of the private subnet. |
| <a name="output_public_subnet_id"></a> [public\_subnet\_id](#output\_public\_subnet\_id) | OCID of the public subnet. |
| <a name="output_vault_crypto_endpoint"></a> [vault\_crypto\_endpoint](#output\_vault\_crypto\_endpoint) | Vault cryptographic operations endpoint, or null when vault is not created. |
| <a name="output_vault_id"></a> [vault\_id](#output\_vault\_id) | OCID of the OCI Vault, or null when vault is not created. |
| <a name="output_vault_management_endpoint"></a> [vault\_management\_endpoint](#output\_vault\_management\_endpoint) | Vault management operations endpoint, or null when vault is not created. |
| <a name="output_vcn_cidr"></a> [vcn\_cidr](#output\_vcn\_cidr) | CIDR block of the VCN. |
| <a name="output_vcn_id"></a> [vcn\_id](#output\_vcn\_id) | OCID of the VCN. |
<!-- END_TF_DOCS -->
