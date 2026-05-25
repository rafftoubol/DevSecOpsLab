variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet to deploy the instance into"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for security group association"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the instance"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS encryption"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "name" {
  description = "Name for the instance"
  type        = string
}
