variable "name" {
  description = "Name prefix for the key alias and IAM policies."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters of lowercase letters, digits, dots and hyphens."
  }
}

variable "force_destroy" {
  description = "Allow destroying a non-empty bucket. Keep false in production."
  type        = bool
  default     = false
}

variable "kms_deletion_window_days" {
  description = "Waiting period before the KMS key is deleted."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "kms_deletion_window_days must be between 7 and 30."
  }
}

variable "noncurrent_version_days" {
  description = "Days to keep noncurrent object versions."
  type        = number
  default     = 90
}
