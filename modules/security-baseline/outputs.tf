output "bucket_id" {
  description = "Bucket name."
  value       = aws_s3_bucket.data.id
}

output "bucket_arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.data.arn
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key."
  value       = aws_kms_key.data.arn
}

output "data_ro_policy_arn" {
  description = "IAM policy granting read-only bucket access."
  value       = aws_iam_policy.data_ro.arn
}

output "data_rw_policy_arn" {
  description = "IAM policy granting read/write (no delete) bucket access."
  value       = aws_iam_policy.data_rw.arn
}
