# Remote state for dev. One state object per environment, one shared bucket and
# lock table (placeholders; created by bootstrap/).
bucket         = "acme-example-terraform-state"
key            = "platform/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "acme-example-terraform-locks"
encrypt        = true
