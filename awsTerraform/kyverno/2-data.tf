data "aws_caller_identity" "current" {}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "wexlop-tf-remote-dev"
    key    = "eks/terraform.tfstate"
    region = "eu-north-1"
  }
}
