locals {
  region       = "eu-north-1"
  env          = "dev"
  cluster_name = "dev-demo"

  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region}.amazonaws.com"
  ecr_image    = "${local.ecr_registry}/devsecops-lab"

  github_workflow_subject = "https://github.com/rafftoubol/DevSecOpsLab/.github/workflows/container-build.yml@refs/heads/master"
  github_oidc_issuer      = "https://token.actions.githubusercontent.com"

  # Namespaces excluded from all admission policies
  system_namespaces = ["kube-system", "kube-public", "kube-node-lease", "kyverno"]
}
