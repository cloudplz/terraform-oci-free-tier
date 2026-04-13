# Example

Deploys the OCI Always Free starter environment using all module defaults.

## Usage

```bash
cd examples/complete
terraform init
terraform apply \
  -var='region=us-phoenix-1' \
  -var='compartment_id=ocid1.compartment.oc1..YOUR_ID' \
  -var='ssh_public_key=ssh-ed25519 AAAA... you@example'
```

Add `tenancy_id` (strongly recommended) to enable the budget safety net and home-region
validation:

```bash
terraform apply \
  -var='region=us-phoenix-1' \
  -var='compartment_id=ocid1.compartment.oc1..YOUR_ID' \
  -var='ssh_public_key=ssh-ed25519 AAAA... you@example' \
  -var='tenancy_id=ocid1.tenancy.oc1..YOUR_ID'
```

## What gets created

| Resource | Detail |
|----------|--------|
| VCN | 10.0.0.0/16 with public and private subnets |
| 3 Arm VMs (A1 Flex) | 4 OCPUs, 24 GB RAM, 200 GB boot volume total |
| MySQL DB System | `MySQL.Free` shape (50 GB, private subnet) |
| Vault + encryption key | Stores MySQL admin password as a secret |
| Flexible Load Balancer | 10 Mbps |
| Network Load Balancer | 1 instance |
| Object Storage bucket | 1 Standard tier bucket |
| Budget + Alert | $1/month safety net (when `tenancy_id` is set) |

To customize features, override variables, or enable paid add-ons like PostgreSQL, see the
module [README](../../README.md) for the full variable reference.

## Cleanup

```bash
terraform destroy \
  -var='region=us-phoenix-1' \
  -var='compartment_id=ocid1.compartment.oc1..YOUR_ID' \
  -var='ssh_public_key=ssh-ed25519 AAAA... you@example'
```
