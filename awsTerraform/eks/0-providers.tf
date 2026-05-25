terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "wexlop-tf-remote-dev"
    key    = "eks/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = local.region
}
