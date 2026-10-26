# Every input that differs between environments. Values live in env/<env>.tfvars;
# nothing here is hard-coded to an account or region.

variable "environment" {
  description = "Environment name, e.g. dev, staging, prod-us-east-1. Must match the file names in env/ and backend/."
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod)(-[a-z]{2}-[a-z]+-[0-9])?$", var.environment))
    error_message = "environment must look like dev, staging or prod-<region>, e.g. prod-us-east-1."
  }
}

variable "region" {
  description = "AWS region this environment is deployed to."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region name, e.g. us-west-2."
  }
}

variable "target_account_id" {
  description = "12-digit ID of the AWS account that hosts this environment. The provider assumes a role in it."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.target_account_id))
    error_message = "target_account_id must be exactly 12 digits."
  }
}

variable "target_role_name" {
  description = "Name of the role to assume in the target account. CI passes terraform-plan for plans and terraform-apply for applies."
  type        = string
  default     = "terraform-plan"
}

variable "permissions_boundary_name" {
  description = "Permissions boundary (created by bootstrap/target-account) attached to every IAM role this stack creates. The apply role refuses to create roles without it."
  type        = string
  default     = "terraform-workload-boundary"
}

variable "org" {
  description = "Short organisation prefix used in resource names."
  type        = string
  default     = "acme"
}

variable "project" {
  description = "Project name used in resource names and the Project tag."
  type        = string
  default     = "platform"
}

variable "owner" {
  description = "Owning team, applied as the Owner tag."
  type        = string
}

variable "cost_center" {
  description = "Cost center identifier, applied as the CostCenter tag for cost allocation."
  type        = string
}

# --- network ---------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block of the environment VPC. Keep non-overlapping across environments so they can be peered later."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Give private subnets outbound internet via NAT. The sample service pulls its image from a public registry, so it needs NAT (or VPC endpoints) to start."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ (cheaper, not AZ-resilient)."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention of VPC flow logs in CloudWatch."
  type        = number
  default     = 14
}

# --- storage ---------------------------------------------------------------

variable "force_destroy" {
  description = "Allow destroying the data bucket while it contains objects. Only ever true outside production."
  type        = bool
  default     = false
}

# --- compute ---------------------------------------------------------------

variable "container_image" {
  description = "Container image for the sample service."
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:stable"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80
}

variable "service_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "service_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "service_desired_count" {
  description = "Number of running tasks."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "Retention of application logs in CloudWatch."
  type        = number
  default     = 30
}
