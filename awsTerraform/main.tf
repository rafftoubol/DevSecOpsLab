data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "wexlop-tf-state-dev"
    key    = "vpc/terraform.tfstate"
    region = "eu-north-1"
  }
}
