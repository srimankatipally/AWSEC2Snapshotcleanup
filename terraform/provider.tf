# Terraform Backend Configuration
# Note: Backend configuration uses partial configuration
# Backend bucket and DynamoDB table are environment-specific
# Use: terraform init -backend-config="bucket=<env>-ec2-snapshot-cleanup" -backend-config="dynamodb_table=<env>-terraform-state-lock"

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }

  # Partial backend configuration - complete via command line or backend config file
  backend "s3" {
    # bucket and dynamodb_table are provided via -backend-config flags
    # or backend config files in backend/ directory
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Environment = var.environment
        ManagedBy   = "Terraform"
        Project     = "EC2-Snapshot-Cleanup"
      },
      var.tags
    )
  }
}

