variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "shared"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state (without environment prefix)"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking (without environment prefix)"
  type        = string
  default     = "terraform-state-lock"
}

variable "tags" {
  description = "Additional tags to apply to backend resources"
  type        = map(string)
  default     = {}
}

