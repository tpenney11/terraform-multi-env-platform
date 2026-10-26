# Values other stacks or humans need from this environment.
output "vpc_id" {
  description = "ID of the environment VPC."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.network.private_subnet_ids
}

output "data_bucket" {
  description = "Name of the encrypted data bucket."
  value       = module.security_baseline.bucket_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.compute.cluster_name
}
