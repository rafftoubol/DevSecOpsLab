# Pre-create the log group so we control retention; EKS would otherwise create
# it with no expiry.
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.eks.arn

  tags = {
    Name = "${local.cluster_name}-logs"
    Env  = local.env
  }
}

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = "1.32"
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    # Restrict to your IP in production:
    # public_access_cidrs = ["x.x.x.x/32"]
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_eks,
    aws_cloudwatch_log_group.eks,
  ]

  tags = {
    Name = local.cluster_name
    Env  = local.env
  }
}
