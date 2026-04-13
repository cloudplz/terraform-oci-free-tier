variable "amd_micro_instances" {
  description = "Map of Always Free AMD Micro instances to create (VM.Standard.E2.1.Micro). Each instance has a fixed 1/8 OCPU and 1 GB RAM. Boot volumes share the 200 GB Always Free budget with A1 instances."
  type = map(object({
    assign_public_ip    = optional(bool, true)
    availability_domain = optional(string)
    boot_volume_gb      = optional(number, 50)
    subnet_role         = optional(string, "public")
  }))
  default = {}

  validation {
    condition     = length(var.amd_micro_instances) <= 2
    error_message = "The OCI Always Free tier supports at most 2 AMD Micro instances."
  }

  validation {
    condition = alltrue([
      for instance in values(var.amd_micro_instances) :
      instance.boot_volume_gb >= 50
    ])
    error_message = "Each AMD Micro boot volume must be at least 50 GB."
  }

  validation {
    condition = alltrue([
      for instance in values(var.amd_micro_instances) :
      contains(["public", "private"], try(instance.subnet_role, "public"))
    ])
    error_message = "Each subnet_role must be either public or private."
  }

  validation {
    condition = alltrue([
      for instance in values(var.amd_micro_instances) :
      !(try(instance.assign_public_ip, true) && try(instance.subnet_role, "public") == "private")
    ])
    error_message = "AMD Micro instances in the private subnet cannot request a public IP."
  }

  validation {
    condition = length(distinct([
      for i in values(var.amd_micro_instances) :
      coalesce(try(i.availability_domain, null), "default")
    ])) <= 1
    error_message = "In multi-AD regions, all AMD Micro instances must use the same availability domain."
  }

  validation {
    condition = (
      sum(concat([for i in values(var.amd_micro_instances) : i.boot_volume_gb], [0])) +
      sum(concat([for i in values(var.compute_instances) : i.boot_volume_gb], [0])) <= 200
    )
    error_message = "Combined boot volume storage across A1 and AMD Micro instances cannot exceed 200 GB."
  }
}

variable "budget_alert_email" {
  description = "Email address for the budget alert rule. When set together with tenancy_id and features.budget, the module creates a $1 monthly budget with an alert that fires when spending reaches the budget amount."
  type        = string
  default     = null
}

variable "budget_amount" {
  description = "Monthly budget amount in the tenancy currency. Only used when features.budget is true and tenancy_id is set."
  type        = number
  default     = 1

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be greater than zero."
  }
}

variable "availability_domain" {
  description = "Default availability domain for compute instances. Set to null to use the first AD returned by OCI unless an instance overrides it."
  type        = string
  default     = null
}

variable "compartment_id" {
  description = "OCID of the compartment where all resources will be created."
  type        = string
}

variable "compute_instances" {
  description = "Map of Always Free A1 instances to create. The default profile exactly consumes 4 OCPUs, 24 GB RAM, and 200 GB boot volume storage."
  type = map(object({
    assign_public_ip    = optional(bool, true)
    availability_domain = optional(string)
    boot_volume_gb      = number
    memory_gb           = number
    ocpus               = number
    subnet_role         = optional(string, "public")
    user_data           = optional(string)
  }))

  default = {
    vm1 = {
      assign_public_ip = true
      boot_volume_gb   = 50
      memory_gb        = 6
      ocpus            = 1
      subnet_role      = "public"
    }
    vm2 = {
      assign_public_ip = true
      boot_volume_gb   = 50
      memory_gb        = 6
      ocpus            = 1
      subnet_role      = "public"
    }
    vm3 = {
      assign_public_ip = true
      boot_volume_gb   = 100
      memory_gb        = 12
      ocpus            = 2
      subnet_role      = "public"
    }
  }

  validation {
    condition     = length(var.compute_instances) >= 1 && length(var.compute_instances) <= 4
    error_message = "compute_instances must contain between 1 and 4 instances."
  }

  validation {
    condition = alltrue([
      for instance in values(var.compute_instances) :
      floor(instance.ocpus) == instance.ocpus && instance.ocpus >= 1
    ])
    error_message = "Each instance must request a whole-number OCPU count greater than or equal to 1."
  }

  validation {
    condition = alltrue([
      for instance in values(var.compute_instances) :
      floor(instance.memory_gb) == instance.memory_gb && instance.memory_gb >= 1
    ])
    error_message = "Each instance must request a whole-number memory size in GB greater than or equal to 1."
  }

  validation {
    condition = alltrue([
      for instance in values(var.compute_instances) :
      instance.boot_volume_gb >= 50
    ])
    error_message = "Each boot volume must be at least 50 GB."
  }

  validation {
    condition = alltrue([
      for instance in values(var.compute_instances) :
      contains(["public", "private"], try(instance.subnet_role, "public"))
    ])
    error_message = "Each subnet_role must be either public or private."
  }

  validation {
    condition = alltrue([
      for instance in values(var.compute_instances) :
      try(instance.availability_domain, null) == null || try(trimspace(instance.availability_domain), "") != ""
    ])
    error_message = "Each instance availability_domain must be null or a non-empty availability domain name."
  }

  validation {
    condition = alltrue([
      for instance in values(var.compute_instances) :
      !(try(instance.assign_public_ip, true) && try(instance.subnet_role, "public") == "private")
    ])
    error_message = "Instances in the private subnet cannot request a public IP."
  }

  validation {
    condition     = sum([for instance in values(var.compute_instances) : instance.ocpus]) <= 4
    error_message = "The OCI Always Free A1 pool supports at most 4 total OCPUs."
  }

  validation {
    condition     = sum([for instance in values(var.compute_instances) : instance.memory_gb]) <= 24
    error_message = "The OCI Always Free A1 pool supports at most 24 total GB of memory."
  }

  validation {
    condition     = sum([for i in values(var.compute_instances) : i.boot_volume_gb]) <= 200
    error_message = "The OCI Always Free pool supports at most 200 total GB of boot and block volume storage."
  }
}

variable "defined_tags" {
  description = "Defined tags applied to all supported OCI resources."
  type        = map(string)
  default     = {}
}

variable "features" {
  description = "Services to provision. Most Always Free services default to true. Boot volume backups and PostgreSQL default to false because they can incur charges with default settings."
  type = object({
    boot_volume_backup    = optional(bool, false)
    budget                = optional(bool, true)
    load_balancer         = optional(bool, true)
    mysql                 = optional(bool, true)
    network_load_balancer = optional(bool, true)
    object_storage        = optional(bool, true)
    postgresql            = optional(bool, false)
    vault                 = optional(bool, true)
  })
  default = {}
}

variable "image_id_override" {
  description = "Optional explicit OCI image OCID for the compute fleet. Use this if the platform image lookup does not return a match in your region or tenancy."
  type        = string
  default     = null
}

variable "freeform_tags" {
  description = "Free-form tags applied to all supported OCI resources."
  type        = map(string)
  default     = {}
}

variable "mysql_admin_password" {
  description = "Optional admin password for the MySQL DB system. Leave null to let Terraform generate one when features.mysql is true."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = (
      var.mysql_admin_password == null ||
      try(
        length(var.mysql_admin_password) >= 8 &&
        length(var.mysql_admin_password) <= 32 &&
        can(regex("[A-Z]", var.mysql_admin_password)) &&
        can(regex("[a-z]", var.mysql_admin_password)) &&
        can(regex("[0-9]", var.mysql_admin_password)) &&
        can(regex("[^a-zA-Z0-9]", var.mysql_admin_password)),
        false
      )
    )
    error_message = "mysql_admin_password must be 8-32 characters and include upper, lower, numeric, and special characters."
  }
}

variable "mysql_admin_username" {
  description = "Admin username for the MySQL DB system."
  type        = string
  default     = "admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.mysql_admin_username)) && length(var.mysql_admin_username) <= 32
    error_message = "mysql_admin_username must start with a letter, contain only alphanumerics and underscores, and be at most 32 characters."
  }
}

variable "load_balancer_backend_instance_keys" {
  description = "Set of compute instance keys to register as load balancer backends. Set to null to register all compute instances."
  type        = set(string)
  default     = null

  validation {
    condition = (
      var.load_balancer_backend_instance_keys == null ||
      try(alltrue([for key in var.load_balancer_backend_instance_keys : contains(keys(var.compute_instances), key)]), false)
    )
    error_message = "All load_balancer_backend_instance_keys must match keys in compute_instances."
  }
}

variable "load_balancer_backend_port" {
  description = "Port the optional load balancer should use to reach its backend instance."
  type        = number
  default     = 80

  validation {
    condition     = var.load_balancer_backend_port >= 1 && var.load_balancer_backend_port <= 65535
    error_message = "load_balancer_backend_port must be between 1 and 65535."
  }
}

variable "load_balancer_listener_port" {
  description = "Port the optional load balancer should expose to clients."
  type        = number
  default     = 80

  validation {
    condition     = var.load_balancer_listener_port >= 1 && var.load_balancer_listener_port <= 65535
    error_message = "load_balancer_listener_port must be between 1 and 65535."
  }
}

variable "name" {
  description = "Name prefix applied to created resources. Keep it short and lowercase."
  type        = string

  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 20 && can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "name must be 1-20 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
}

variable "network_load_balancer_port" {
  description = "Port for the optional network load balancer listener and backends."
  type        = number
  default     = 80

  validation {
    condition     = var.network_load_balancer_port >= 1 && var.network_load_balancer_port <= 65535
    error_message = "network_load_balancer_port must be between 1 and 65535."
  }
}

variable "object_storage_bucket_name" {
  description = "Optional explicit bucket name. Leave null to let Terraform generate a unique one."
  type        = string
  default     = null
}

variable "postgresql_admin_password" {
  description = "Optional admin password for the PostgreSQL DB system. Leave null to let Terraform generate one when features.postgresql is true."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = (
      var.postgresql_admin_password == null ||
      try(
        length(var.postgresql_admin_password) >= 8 &&
        length(var.postgresql_admin_password) <= 32 &&
        can(regex("[A-Z]", var.postgresql_admin_password)) &&
        can(regex("[a-z]", var.postgresql_admin_password)) &&
        can(regex("[0-9]", var.postgresql_admin_password)) &&
        can(regex("[^a-zA-Z0-9]", var.postgresql_admin_password)),
        false
      )
    )
    error_message = "postgresql_admin_password must be 8-32 characters and include upper, lower, numeric, and special characters."
  }
}

variable "postgresql_admin_username" {
  description = "Admin username for the PostgreSQL DB system."
  type        = string
  default     = "pgadmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.postgresql_admin_username)) && length(var.postgresql_admin_username) <= 32
    error_message = "postgresql_admin_username must start with a letter, contain only alphanumerics and underscores, and be at most 32 characters."
  }
}

variable "postgresql_db_version" {
  description = "PostgreSQL major version for the DB system."
  type        = string
  default     = "16"

  validation {
    condition     = contains(["14", "15", "16"], var.postgresql_db_version)
    error_message = "postgresql_db_version must be 14, 15, or 16."
  }
}

variable "postgresql_shape" {
  description = "Shape name for the PostgreSQL DB system. Uses the flexible shape with OCPU/memory controlled by postgresql_instance_ocpu_count and postgresql_instance_memory_size_in_gbs."
  type        = string
  default     = "PostgreSQL.VM.Standard.E5.Flex"
}

variable "postgresql_instance_ocpu_count" {
  description = "Number of OCPUs for the PostgreSQL DB system. Minimum 1."
  type        = number
  default     = 1

  validation {
    condition     = var.postgresql_instance_ocpu_count >= 1
    error_message = "postgresql_instance_ocpu_count must be at least 1."
  }
}

variable "postgresql_instance_memory_size_in_gbs" {
  description = "Memory in GB for the PostgreSQL DB system. Minimum 16 GB per OCPU."
  type        = number
  default     = 16

  validation {
    condition = (
      var.postgresql_instance_memory_size_in_gbs >= 16 &&
      var.postgresql_instance_memory_size_in_gbs >= var.postgresql_instance_ocpu_count * 16
    )
    error_message = "postgresql_instance_memory_size_in_gbs must be at least 16 GB and at least 16 GB per OCPU."
  }
}

variable "operating_system" {
  description = "OCI platform image operating system for the compute fleet."
  type        = string
  default     = "Ubuntu"

  validation {
    condition     = contains(["Oracle Linux", "Ubuntu"], var.operating_system)
    error_message = "operating_system must be Oracle Linux or Ubuntu."
  }
}

variable "operating_system_version" {
  description = "Optional OCI platform image operating system version filter. Leave null to let OCI choose the newest image for the selected OS."
  type        = string
  default     = null
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet."
  type        = string
  default     = "10.0.2.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "private_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "ssh_ingress_cidr" {
  description = "Optional CIDR allowed to SSH into the compute fleet. Set null to create no SSH ingress rule."
  type        = string
  default     = null

  validation {
    condition     = var.ssh_ingress_cidr == null || can(cidrhost(var.ssh_ingress_cidr, 0))
    error_message = "ssh_ingress_cidr must be null or a valid IPv4 CIDR block."
  }
}

variable "ssh_public_key" {
  description = "SSH public key added to each compute instance via cloud-init metadata."
  type        = string

  validation {
    condition = (
      can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-)", trimspace(var.ssh_public_key)))
    )
    error_message = "ssh_public_key must look like a valid OpenSSH public key."
  }
}

variable "tenancy_id" {
  description = "Optional tenancy OCID for home-region validation. When set, the module warns if resources are not being created in the tenancy home region where Always Free allowances apply."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Optional cloud-init or shell script user data. The module base64-encodes it before sending it to OCI."
  type        = string
  default     = null
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "vcn_cidr must be a valid IPv4 CIDR block."
  }
}
