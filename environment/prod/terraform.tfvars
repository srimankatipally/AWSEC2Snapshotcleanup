# Prod Environment Configuration
aws_region             = "us-west-2"
environment            = "prod"
vpc_cidr               = "10.0.0.0/16"
snapshot_retention_days = 365
schedule_expression    = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
lambda_function_name   = "ec2-snapshot-cleanup"
exclude_tag_key        = ""
exclude_tag_value      = ""

tags = {
  Environment = "prod"
  ManagedBy   = "Terraform"
  Project     = "EC2-Snapshot-Cleanup"
}

