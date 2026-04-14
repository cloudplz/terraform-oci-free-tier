# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-04-14

### Added

- Fleet profiles via `profile` with `balanced` as the new default
- Block volume support via `block_volumes`, including a new `block_volumes` output
- Auto-mount cloud-init for one mount-point-bearing block volume per compute instance, with retry cron behavior
- New `enable_keepalive` variable to control the idle-prevention cron setup
- Plan-time checks for total storage budget, block volume attachment targets, block volume mount-point uniqueness, and effective load balancer backend keys
- HCP Terraform guidance in the README for OCI credentials that must be passed as Terraform variables
- Expanded tests covering profile behavior, keepalive/mount user data, and new validation rules

### Changed

- **BREAKING**: removed the `operating_system` input and standardized platform image selection on Ubuntu 24.04
- Default fleet now comes from the `balanced` profile: 3 A1 VMs with 150 GB of boot volume storage and one 50 GB attached block volume
- Compute, backup, image lookup, and outputs logic now consistently use effective profile-backed values instead of raw input maps
- Boot volume validation remains at a 50 GB minimum and the README now documents the new profile-based layout and block volume behavior

### Fixed

- `load_balancer_backend_instance_keys` validation now works correctly with profile-backed defaults and no longer fails CI on null input
- CI formatting drift after the profile/block-volume refactor was cleaned up

## [1.0.0] - 2026-04-13

### Added

- `.tflint.hcl` with Terraform ruleset configuration for repository linting
- Terraform Registry and Latest Release badges in the README
- Improved `examples/complete/README.md` usage and service inventory documentation

### Changed

- Moved the example provider configuration out of `examples/complete/main.tf` into `examples/complete/terraform.tf` so the published module is Terraform Registry compliant
- Refined the complete example structure and docs as part of the initial registry publishing prep

## [0.7.0] - 2026-04-13

### Added

- OCI Vault integration: database admin passwords are now stored as Vault secrets (Always Free -- up to 150 secrets per tenancy)
- New `features.vault` flag (defaults to `true`); vault is created when any database feature is enabled
- New resources: `oci_kms_vault.main`, `oci_kms_key.secrets`, `oci_vault_secret.mysql_admin_password`, `oci_vault_secret.postgresql_admin_password`
- New outputs: `vault_id`, `vault_crypto_endpoint`, `vault_management_endpoint`, `mysql_admin_password_secret_id`, `postgresql_admin_password_secret_id`
- IAM guidance for vault, key, and secret management policies
- Vault tests for default creation, disabled state, and PostgreSQL secret

### Changed

- Updated Known OCI Caveats to reflect passwords being stored in Vault instead of recommending external Vault setup
- Moved OCI Vault / Key Management from "Not Yet Implemented" to "Implemented" in Always Free Coverage

## [0.6.0] - 2026-04-13

### Changed

- **BREAKING**: `features.boot_volume_backup` now defaults to `false` (was `true`) to avoid silently exceeding the 5-backup Always Free limit
- Renamed all "MySQL HeatWave" references to "MySQL DB System" for accuracy (the separate HeatWave cluster is not yet implemented)
- PostgreSQL default shape changed from `PostgreSQL.VM.Standard.E5.Flex.2.32GB` (2 OCPU / 32 GB) to `PostgreSQL.VM.Standard.E5.Flex` (1 OCPU / 16 GB) to reduce accidental cost
- Budget alert wording corrected from "any spending" to "spending reaches the budget amount"
- A1 instances now round-robin across availability domains by default instead of all landing in AD-1

### Added

- AMD Micro same-AD validation: all E2.1.Micro instances must use the same availability domain
- New variables: `postgresql_instance_ocpu_count`, `postgresql_instance_memory_size_in_gbs`
- Always Free Coverage section in README listing implemented vs missing OCI services
- Home-region caution banner in README prerequisites
- Validation test for AMD Micro multi-AD rejection

### Fixed

- Object Storage docs now accurately describe 20 GB total across Standard + IA + Archive tiers
- terraform-docs block updated to reflect current resources, inputs, and outputs (removed stale ADB references)
- Example README and variable descriptions cleaned of stale "HeatWave" and "Autonomous Database" references
- Minimal example no longer hardcodes tenancy-specific availability domain names
- Minimal example README now accurately lists all default resources created

## [0.5.0] - 2026-04-13

### Added

- Optional OCI Database with PostgreSQL via `features.postgresql` (disabled by default -- **paid resource**)
- New variables: `postgresql_admin_username`, `postgresql_admin_password`, `postgresql_db_version`, `postgresql_shape`
- New outputs: `postgresql_db_system_id`, `postgresql_db_system_ip_address`, `postgresql_admin_password`
- PostgreSQL security list for port 5432, conditionally attached to the private subnet
- PostgreSQL admin password auto-generation via `random_password.postgresql_admin`
- Secrets management guidance in README (OCI Vault recommendation, ephemeral resource limitations)

### Removed

- Oracle Autonomous Database (`oci_database_autonomous_database.main`) and all related variables (`database_admin_password`, `database_workload`), outputs, and the `features.database` flag (**BREAKING**)

### Changed

- Updated complete example to include PostgreSQL opt-in pattern
- README reorganized to reflect removal of ADB and addition of PostgreSQL

## [0.4.0] - 2026-04-13

### Added

- Budget safety net via `oci_budget_budget` and `oci_budget_alert_rule` — creates a $1/month budget with an alert on any spending when `tenancy_id` is set
- New variables: `features.budget`, `budget_amount`, `budget_alert_email`
- New output: `budget_id`
- Pre-commit configuration (`.pre-commit-config.yaml`) using `antonbabenko/pre-commit-terraform` v1.105.0 and `pre-commit/pre-commit-hooks` v6.0.0
- `pre-commit` Makefile target
- IAM note in README for tenancy-level `usage-budgets` policy
- Budget unit tests for conditional creation and alert rule behavior

### Changed

- Merged `mysql.tf` into `database.tf` and moved MySQL security list into `network.tf` to align with OCI Always Free categories (**BREAKING** for anyone importing by file path)
- Rewrote "What The Module Creates" README section as an explicit resource inventory organized by OCI Always Free category (Infrastructure, Database, Networking, Governance)

## [0.3.0] - 2026-04-13

### Added

- MySQL HeatWave Always Free DB system via `features.mysql` using `MySQL.Free` shape (50 GB, 8 GB RAM, no HA)
- MySQL admin password auto-generation via `random_password.mysql_admin` when `mysql_admin_password` is null
- MySQL security list allowing ports 3306 and 33060 from the VCN CIDR, conditionally attached to the private subnet
- New outputs: `mysql_db_system_id`, `mysql_db_system_ip_address`, `mysql_admin_password`
- Charge-risk comments on every resource file documenting whether charges are structurally impossible or require monitoring
- "Resources That Cannot Incur Charges" and "Resources That Can Incur Charges" sections in README

### Changed

- All `features` flags now default to `true` to maximize Always Free utilization (**BREAKING**)
- Removed `prevent_destroy` lifecycle on Autonomous Database and Object Storage bucket for clean teardown (**BREAKING**)
- Updated complete example to include MySQL and tenancy home-region validation
- README reorganized to lead with "all services enabled by default" messaging

## [0.2.0] - 2026-04-13

### Added

- Home-region validation via optional `tenancy_id` variable with a `check` block that warns when the OCI provider targets a non-home region
- AMD Micro compute support (`VM.Standard.E2.1.Micro`) via new `amd_micro_instances` variable, up to 2 instances
- Network Load Balancer support via `features.network_load_balancer` with dedicated NSG and Layer 3/4 pass-through
- NAT gateway auto-created when any compute instance uses `subnet_role = "private"`
- ICMP ingress rules (path MTU discovery and echo request) on the compute NSG
- Boot volume backup policy attachment via `features.boot_volume_backup` using the Oracle-defined bronze policy
- Per-instance `user_data` field on `compute_instances`, falling back to the global `user_data` variable
- New outputs: `amd_micro_instances`, `autonomous_database_connection_strings`, `network_load_balancer_id`, `network_load_balancer_ip_addresses`, `object_storage_namespace`, `vcn_cidr`
- Always Free Limits Reference table in the README
- Combined boot volume validation across A1 and AMD Micro instances

### Changed

- `load_balancer_backend_instance_key` (singular) replaced with `load_balancer_backend_instance_keys` (set); defaults to registering all compute instances as backends (**BREAKING**)
- `features` object now includes `boot_volume_backup` and `network_load_balancer` fields
- `database_workload` validation now accepts `AJD` (Autonomous JSON Database) in addition to `APEX` and `OLTP`
- Object Storage bucket now explicitly sets `storage_tier = "Standard"`
- Compute instances now use `ignore_changes` on `source_details[0].source_id` to prevent image drift recreation
- Private route table now includes a default route through the NAT gateway when applicable

### Fixed

- Private subnet was a dead end with no outbound route; now gets a NAT gateway automatically
- Load balancer only supported a single backend; now supports multiple backends via `for_each`

### Security

- Autonomous Database and Object Storage bucket now have `prevent_destroy = true` lifecycle protection

## [0.1.0] - 2026-04-12

### Added

- Initial public release of the OCI Always Free starter module
- Default 3-VM OCI Ampere A1 fleet sized to fully consume the Always Free A1 quota
- Core networking stack with VCN, public/private subnets, internet gateway, route tables, and NSGs
- Optional Object Storage bucket, Always Free Autonomous Database, and flexible 10 Mbps load balancer
- Variable validation enforcing Always Free compute and storage pool limits
- Minimal and complete example configurations
- Mock-based Terraform unit tests for defaults and validation failures
- GitHub Actions CI for formatting, validation, example validation, and tests
- `terraform-docs` configuration and helper Makefile targets

[1.0.2]: https://github.com/cloudplz/terraform-oci-free-tier/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/cloudplz/terraform-oci-free-tier/releases/tag/v1.0.0
[0.7.0]: https://github.com/cloudplz/terraform-oci-free-tier/releases/tag/v0.7.0
[0.6.0]: https://github.com/cloudplz/terraform-oci-free-tier/releases/tag/v0.6.0
[0.5.0]: https://github.com/cloudplz/terraform-oci-free-tier/releases/tag/v0.5.0
[0.4.0]: https://github.com/cloudplz/terraform-oci-free-tier/releases/tag/v0.4.0
[0.3.0]: https://github.com/cloudplz/terraform-oci-free-tier/releases/tag/v0.3.0
[0.2.0]: https://github.com/cloudplz/terraform-oci-free-tier/releases/tag/v0.2.0
[0.1.0]: https://github.com/cloudplz/terraform-oci-free-tier/releases/tag/v0.1.0
