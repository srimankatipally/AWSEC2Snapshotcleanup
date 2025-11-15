# Generate a random suffix for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
  keepers = {
    environment = var.environment
    bucket_name = var.bucket_name
  }
}

