output "allowlist_bucket_name" {
  value = module.security_allowlists.bucket_id
}

output "allowlist_bucket_arn" {
  value = module.security_allowlists.bucket_arn
}

output "kms_key_arn" {
  value = aws_kms_key.security.arn
}
output "github_pipeline_role_arn" {
  value = aws_iam_role.github_security_pipeline.arn
}
