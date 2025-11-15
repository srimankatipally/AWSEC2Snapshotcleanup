variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "snapshot_retention_days" {
  description = "Number of days to retain snapshots before deletion"
  type        = number
  default     = 365
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule expression for Lambda trigger"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "ec2-snapshot-cleanup"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "exclude_tag_key" {
  description = "Optional tag key to exclude snapshots from deletion (e.g., 'KeepSnapshot')"
  type        = string
  default     = ""
}

variable "exclude_tag_value" {
  description = "Optional tag value to exclude snapshots from deletion (e.g., 'true')"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

