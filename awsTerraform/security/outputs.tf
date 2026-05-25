output "allowlist_bucket_name" {
  value = module.security_allowlists.bucket_id
}

output "allowlist_bucket_arn" {
  value = module.security_allowlists.bucket_arn
}

output "kms_key_arn" {
  value = aws_kms_key.security.arn
}
