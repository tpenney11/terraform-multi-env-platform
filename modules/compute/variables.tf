variable "name" {
  description = "Name prefix for all resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC the service runs in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the tasks."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Provide at least two subnets so tasks span availability zones."
  }
}

variable "container_image" {
  description = "Container image URI."
  type        = string
}

variable "container_port" {
  description = "Container port."
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Fargate CPU units."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be one of 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Fargate memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of running tasks."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count cannot be negative."
  }
}

variable "log_retention_days" {
  description = "CloudWatch retention for application logs."
  type        = number
  default     = 30
}

variable "task_policy_arns" {
  description = "Map of static key => IAM policy ARN attached to the task role."
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "Plain (non-secret) environment variables. Use Secrets Manager or SSM references for secrets."
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary attached to every IAM role this module creates. Null for none."
  type        = string
  default     = null
}
