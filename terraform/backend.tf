# Terraform Backend Configuration
# Configured to use existing S3 bucket: ec2-snapshot-cleanup

terraform {
  backend "s3" {
    bucket         = "ec2-snapshot-cleanup"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    # dynamodb_table = "terraform-state-lock"  # Optional: uncomment if you have DynamoDB table for locking
  }
}

