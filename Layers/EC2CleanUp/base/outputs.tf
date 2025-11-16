output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "bucket_suffix" {
  description = "Random suffix used in bucket name for uniqueness"
  value       = random_id.bucket_suffix.hex
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}



