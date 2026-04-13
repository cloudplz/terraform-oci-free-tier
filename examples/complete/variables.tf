variable "compartment_id" {
  description = "OCID of the target compartment."
  type        = string
}

variable "region" {
  description = "OCI home region for Always Free resources (e.g. us-phoenix-1)."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for the compute instances."
  type        = string
}

variable "tenancy_id" {
  description = "Tenancy OCID for home-region validation and budget creation. Strongly recommended."
  type        = string
  default     = null
}
