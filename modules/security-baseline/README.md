# security-baseline

An S3 bucket that is secure by default, plus the IAM policies to use it.

- KMS customer-managed key, rotation on, SSE-KMS with bucket keys.
- Public access block on all four settings; ACLs disabled (`BucketOwnerEnforced`).
- Bucket policy denying any request where `aws:SecureTransport` is false.
- Versioning with noncurrent-version expiry and multipart cleanup.
- `data_ro` and `data_rw` IAM policies scoped to this bucket and key only.
  Writers cannot delete objects.

```hcl
module "security_baseline" {
  source      = "./modules/security-baseline"
  name        = "acme-platform-dev"
  bucket_name = "acme-platform-dev-data-111111111111"
}
```

Outputs: `bucket_id`, `bucket_arn`, `kms_key_arn`, `data_ro_policy_arn`,
`data_rw_policy_arn`.
