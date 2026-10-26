# Environment: staging. Contains no secrets; account IDs are example placeholders.
environment       = "staging"
region            = "us-east-1"
target_account_id = "222222222222"

owner       = "platform-team"
cost_center = "cc-1002"

vpc_cidr           = "10.20.0.0/16"
az_count           = 2
enable_nat_gateway = true
single_nat_gateway = true

force_destroy         = true
service_desired_count = 2
log_retention_days    = 30
