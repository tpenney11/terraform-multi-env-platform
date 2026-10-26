variable "region" {
  description = "Region of the state bucket and lock table."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique name of the Terraform state bucket."
  type        = string
  default     = "acme-example-terraform-state"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB lock table."
  type        = string
  default     = "acme-example-terraform-locks"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, as owner/name."
  type        = string
  default     = "acme/terraform-multi-env-platform"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}

variable "environments" {
  description = "Map of environment name => target account ID. Drives per-environment apply roles and plan permissions."
  type        = map(string)
  default = {
    "dev"               = "111111111111"
    "staging"           = "222222222222"
    "prod-us-east-1"    = "333333333333"
    "prod-us-west-2"    = "333333333333"
    "prod-eu-central-1" = "333333333333"
  }
}

variable "state_key_prefix" {
  description = "Prefix under which each environment stores its state object: <prefix>/<env>/terraform.tfstate."
  type        = string
  default     = "platform"
}

variable "target_plan_role_name" {
  description = "Role name (same in every target account) that plans assume. Read-only."
  type        = string
  default     = "terraform-plan"
}

variable "target_apply_role_name" {
  description = "Role name (same in every target account) that applies assume."
  type        = string
  default     = "terraform-apply"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "CostCenter tag."
  type        = string
  default     = "cc-0001"
}
