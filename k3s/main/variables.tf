# GENERAL VARIABLES
variable "location" {
  default     = "northeurope"
  description = "location of the resource group, must be a valid Azure location"
  validation {
    condition     = can(regex("^(westeurope|northeurope|uksouth|ukwest|eastus|eastus2|westus|westus2|centralus|northcentralus|southcentralus|westcentralus|canadacentral|canadaeast|brazilsouth|australiaeast|australiasoutheast|australiacentral|australiacentral2|eastasia|southeastasia|japaneast|japanwest|koreacentral|koreasouth|southindia|westindia|centralindia|francecentral|francesouth|germanywestcentral|norwayeast|swedencentral|switzerlandnorth|switzerlandwest|uaenorth|uaecentral|southafricanorth|southafricawest|eastus2euap|westus2euap|westcentralus|westus3|southafricawest2|australiacentral|australiacentral2|australiaeast|australiasoutheast|brazilsouth|canadacentral|canadaeast|centralindia|centralus|eastasia|eastus|eastus2|francecentral|francesouth|germanywestcentral|japaneast|japanwest|koreacentral|koreasouth|northcentralus|northeurope|norwayeast|southcentralus|southindia|southeastasia|swedencentral|switzerlandnorth|switzerlandwest|uaecentral|uaenorth|uksouth|ukwest|westcentralus|westeurope|westindia|westus|westus2)$", var.location))
    error_message = "location must be a valid Azure location"
  }
}

variable "customer" {
  description = "shorthand abbrieviation for customer name, must only contain lowercase letters and numbers"
  validation {
    condition     = can(regex("^[a-z0-9]+$", var.customer))
    error_message = "customer must only contain lowercase letters and numbers"
  }
}


variable "da_version" {
  description = "version of carbacc to deploy"
}

variable "dex_version" {
  description = "version of dex to deploy"
}

variable "domain" {
  default = "afcsoftware.com"
  description = "Star domain used by the proxy Eg. afcsoftware.com for customer1.afcsoftware.com"
}

# CONTAINER REGISTRY VARIABLES
variable "container_registry" {
  default     = "imagesdevregistry.azurecr.io"
  description = "container registry url"
}

variable "container_registry_username" {
  description = "container registry username, must not be empty"
  validation {
    condition     = can(regex("^.{1,}$", var.container_registry_username))
    error_message = "container_registry_username must not be empty"
  }
}

variable "container_registry_password" {
  description = "container registry password, must not be empty"
  validation {
    condition     = can(regex("^.{1,}$", var.container_registry_password))
    error_message = "container_registry_password must not be empty"
  }
}

# CONTAINER VARIABLES

variable "min_cpu" {
  default     = 0.50
  description = "minimum cpu"
}

variable "min_memory" {
  default     = "1Gi"
  description = "minimum memory"
}

variable "database_user" {
  description = "database admin user, must only contain lowercase letters and numbers"
  validation {
    condition     = can(regex("^[a-z0-9]+$", var.database_user))
    error_message = "database_user must only contain lowercase letters and numbers"
  }
}

variable "database_password" {
  description = "database admin password, must be at least 8 characters long"
  validation {
    condition     = can(regex("^.{8,}$", var.database_password))
    error_message = "dbpassword must be at least 8 characters long"
  }
}

# SCALING VARIABLES
variable "min_replicas" {
  default     = 0
  description = "minimum number of replicas, must be a number, use 0 to allow scaling to 0 to reduce costs"
  validation {
    condition     = can(regex("^[0-9]+$", var.min_replicas))
    error_message = "min_replicas must be a number"
  }
}
variable "max_replicas" {
  default     = 10
  description = "maximum number of replicas, must be a number"
  validation {
    condition     = can(regex("^[0-9]+$", var.max_replicas))
    error_message = "max_replicas must be a number"
  }
}
# SMTP VARIABLES
variable "smtp_host" {
  description = "SMTP host"
}
variable "smtp_port" {
  description = "SMTP port, must be a number"
  validation {
    condition     = can(regex("^[0-9]+$", var.smtp_port))
    error_message = "SMTP port must be a number"
  }
}
variable "smtp_username" {
  description = "SMTP username"
}
variable "smtp_password" {
  description = "SMTP password"
}
variable "smtp_from" {
  description = "SMTP from address, must be a valid email address"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.smtp_from))
    error_message = "SMTP from address must be a valid email address"
  }
}

# APPLICATION ADMIN VARIABLES
variable "app_admin_email" {
  description = "Application admin email, must be a valid email address"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.app_admin_email))
    error_message = "Application admin email must be a valid email address"
  }
}

variable "app_admin_first_name" {
  description = "Application admin first name"
}

variable "app_admin_last_name" {
  description = "Application admin last name"
}

variable "storage_quota" {
  default = 100
  description = "storage quota in GB, must be a number"
  validation {
    condition = can(regex("^[0-9]+$", var.storage_quota))
    error_message = "storage_quota must be a number"
  }
}
variable "storage_access_tier" {
  default = "Hot"
  description = "storage access tier, must be a valid Azure storage access tier"
  validation {
    condition = can(regex("^(Hot|Cool)$", var.storage_access_tier))
    error_message = "storage_access_tier must be a valid Azure storage access tier"
  }
}

variable "storage_account_name" {
  description = "storage account name, must be a valid Azure storage account name"
  default = ""
}

# K3s Variables

variable "ssh_public_key" {
  description = "ssh public key, must be a valid ssh public key"
}

variable "ssh_private_key" {
  description = "ssh private key, must be a valid ssh private key"
}

variable "github_client_id" {
  description = "Client secret for github"
  type        = string
  default     = "null"
}

variable "github_client_secret" {
  description = "Secret for the client"
  type        = string
  default     = "null"
}

variable "sso_issuer" {
  description = "Issuer for sso"
  type        = string
  default     = "null"
}

variable "sso_client_id" {
  description = "Client id for sso"
  type        = string
  default     = "null"
}

variable "sso_client_secret" {
  description = "Client secret for sso"
  type        = string
  default     = "null"
}

variable "microsoft_client_id" {
  description = "Client id for microsoft"
  type        = string
  default     = "null"
}

variable "microsoft_client_secret" {
  description = "Client secret for microsoft"
  type        = string
  default     = "null"
}

# VM Control

variable "is_development" {
  description = "Whether the deployment is in development mode"
  type        = bool
  default     = false
}

variable "k3s_token" {
  description = "Token for k3s"
  type        = string
  default     = "null"
}

