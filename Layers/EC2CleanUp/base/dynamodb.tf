# DynamoDB Table for Terraform State Locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${var.environment}-${var.dynamodb_table_name}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    {
      Name        = "${var.environment}-${var.dynamodb_table_name}"
      Environment = var.environment
      Purpose     = "Terraform State Locking"
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

