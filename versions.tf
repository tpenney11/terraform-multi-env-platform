# Provider and Terraform version constraints for the root configuration.
# The backend block is intentionally empty (partial configuration): bucket,
# key, region and lock table come from backend/<env>.hcl at init time.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}
