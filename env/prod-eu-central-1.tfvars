# Environment: prod-eu-central-1. Contains no secrets; account IDs are example placeholders.
environment       = "prod-eu-central-1"
region            = "eu-central-1"
target_account_id = "333333333333"

owner       = "platform-team"
cost_center = "cc-2001"

vpc_cidr           = "10.32.0.0/16"
az_count           = 3
enable_nat_gateway = true
single_nat_gateway = false

force_destroy         = false
service_desired_count = 3
log_retention_days    = 90
