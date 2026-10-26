# Environment: dev. Contains no secrets; account IDs are example placeholders.
environment       = "dev"
region            = "us-east-1"
target_account_id = "111111111111"

owner       = "platform-team"
cost_center = "cc-1001"

vpc_cidr           = "10.10.0.0/16"
az_count           = 2
enable_nat_gateway = true
single_nat_gateway = true

force_destroy         = true
service_desired_count = 1
log_retention_days    = 7
