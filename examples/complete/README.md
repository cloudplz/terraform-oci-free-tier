# Complete Example

Deploys all features enabled — 3 Arm VMs, MySQL, load balancers, Object Storage, and a KMS vault.

## Usage

```bash
cd examples/complete
terraform init
terraform apply \
  -var='compartment_id=ocid1.compartment.oc1..your_compartment' \
  -var='region=us-phoenix-1' \
  -var='ssh_public_key=ssh-ed25519 AAAA... user@example'
```

## What gets created

| Service | Detail |
|---------|--------|
| Compute | 3 Ampere A1 Flex VMs (4 OCPUs, 24 GB RAM, 200 GB boot) |
| MySQL | MySQL.Free DB System, 50 GB storage |
| Flexible Load Balancer | HTTP listener on port 80 |
| Network Load Balancer | TCP listener on port 22 |
| Object Storage | Encrypted bucket |
| Vault | KMS vault + secrets for database passwords |
| VCN | Public + private subnets, NAT gateway (if private instances) |

## Cleanup

```bash
terraform destroy \
  -var='compartment_id=ocid1.compartment.oc1..your_compartment' \
  -var='region=us-phoenix-1' \
  -var='ssh_public_key=ssh-ed25519 AAAA... user@example'
```
