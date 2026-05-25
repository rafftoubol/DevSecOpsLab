module "security_allowlists" {
  source = "../modules/secure-s3"

  bucket_name        = "wexlop-security-allowlists"
  environment        = "dev"
  kms_key_arn        = aws_kms_key.security.arn
  allowed_principals = []
}
