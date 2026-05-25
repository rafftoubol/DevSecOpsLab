# modules/s3-secure/variables.tf
variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of KMS key for encryption"
}

variable "allowed_principals" {
  type        = list(string)
  description = "List of IAM principal ARNs allowed to access the bucket"
  default     = []
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket to be destroyed with objects inside"
  default     = false
}
