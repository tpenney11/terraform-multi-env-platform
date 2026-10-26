# Bootstrap stack: run once (locally, with admin credentials in the shared tooling
# account) to create the state backend and the CI identities. It uses local state
# by design; keep that state somewhere safe or import it into the backend later.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.81"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "shared"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Project     = "platform"
      ManagedBy   = "terraform"
    }
  }
}
