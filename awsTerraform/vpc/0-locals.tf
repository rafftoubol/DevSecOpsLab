locals {
  region   = "eu-north-1"
  vpc_cidr = "10.0.0.0/16"
  name     = "DevSecOpsLab"
  env      = "dev"

  azs             = ["eu-north-1a", "eu-north-1b"]
  public_subnets  = ["10.0.0.0/19", "10.0.32.0/19"]
  private_subnets = ["10.0.64.0/19", "10.0.96.0/19"]

}
