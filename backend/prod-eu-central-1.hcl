# Remote state for prod-eu-central-1. One state object per environment, one shared bucket and
# lock table (placeholders; created by bootstrap/).
bucket         = "acme-example-terraform-state"
key            = "platform/prod-eu-central-1/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "acme-example-terraform-locks"
encrypt        = true
