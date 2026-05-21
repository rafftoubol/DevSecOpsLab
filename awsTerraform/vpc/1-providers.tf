provider "aws" {
  region = local.region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
  backend "s3" {
    bucket = "wexlop-tf-remote-dev"
    key    = "vpc/terraform.tfstate"
    region = "eu-north-1"
  }

  required_version = ">= 1.2"
}
