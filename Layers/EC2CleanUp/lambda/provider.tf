# Terraform Backend Configuration
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
}


terraform {
  backend "s3" {

    key     = "terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
    use_lockfile = true
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

