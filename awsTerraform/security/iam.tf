data "aws_caller_identity" "current" {}

# OIDC provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Role that GitHub Actions assumes via OIDC
resource "aws_iam_role" "github_security_pipeline" {
  name = "github-security-pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:rafftoubol/*:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Policy — ECR push, pull, and OCI artifact write (for cosign signatures/attestations)
resource "aws_iam_role_policy" "github_ecr" {
  name = "ecr"
  role = aws_iam_role.github_security_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "arn:aws:ecr:eu-north-1:${data.aws_caller_identity.current.account_id}:repository/devsecops-lab"
      }
    ]
  })
}

# Policy — read only on the allowlist bucket
resource "aws_iam_role_policy" "github_security_pipeline" {
  name = "allowlist-read"
  role = aws_iam_role.github_security_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${module.security_allowlists.bucket_arn}/allowlists/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = module.security_allowlists.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.security.arn
      }
    ]
  })
}
