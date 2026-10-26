output "state_bucket" {
  description = "State bucket name (goes into backend/*.hcl)."
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "Lock table name (goes into backend/*.hcl)."
  value       = aws_dynamodb_table.locks.name
}

output "plan_role_arn" {
  description = "Set as the PLAN_ROLE_ARN repository variable in GitHub."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arns" {
  description = "Per environment; set as APPLY_ROLE_ARN on the matching GitHub Environment."
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}

output "tooling_account_id" {
  description = "Account that hosts the state backend and CI roles."
  value       = data.aws_caller_identity.current.account_id
}
