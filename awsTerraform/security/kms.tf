resource "aws_kms_key" "security" {
  description             = "KMS key for security allowlist bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "security" {
  name          = "alias/security-allowlists"
  target_key_id = aws_kms_key.security.key_id
}
