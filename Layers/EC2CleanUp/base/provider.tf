provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        ManagedBy = "Terraform"
        Project   = "EC2-Snapshot-Cleanup"
      },
      var.tags
    )
  }
}

