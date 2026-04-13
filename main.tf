# OCI Always Free Tier Module
#
# Resources are organized by concern:
#   compute.tf              - A1 Flex and AMD Micro instances
#   network.tf              - VCN, subnets, security lists, NSG, gateways
#   load_balancer.tf         - HTTP load balancer
#   network_load_balancer.tf - Network load balancer (TCP/UDP)
#   database.tf              - MySQL and PostgreSQL DB systems
#   object_storage.tf        - Object Storage bucket
#   vault.tf                 - KMS vault, key, and secrets
#   budget.tf                - Budget and alert rules
#   backup.tf                - Boot volume backup policy assignments
#   support.tf               - Support resource
