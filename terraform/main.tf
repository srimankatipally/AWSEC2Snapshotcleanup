# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-snapshot-cleanup-vpc"
  }
}

# Private Subnets (for Lambda and VPC Endpoints)
resource "aws_subnet" "private" {
  for_each = {
    for idx, az in slice(data.aws_availability_zones.available.names, 0, 2) : idx => az
  }
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.key)
  availability_zone = each.value

  tags = {
    Name = "${var.environment}-snapshot-cleanup-private-${each.key + 1}"
    Type = "private"
  }
}

# Route Table for Private Subnets (no internet routes needed)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-snapshot-cleanup-private-rt"
  }
}

# Route Table Association for Private Subnets
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.environment}-snapshot-cleanup-lambda-sg"
  description = "Security group for Lambda function to access AWS APIs via VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-snapshot-cleanup-lambda-sg"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${var.environment}-snapshot-cleanup-vpc-endpoint-sg"
  description = "Security group for VPC Endpoints to allow Lambda access"
  vpc_id      = aws_vpc.main.id

  # Allow inbound HTTPS from Lambda
  ingress {
    description     = "HTTPS from Lambda"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  tags = {
    Name = "${var.environment}-snapshot-cleanup-vpc-endpoint-sg"
  }
}

# Security group rule for Lambda egress (added separately to avoid circular dependency)
resource "aws_security_group_rule" "lambda_egress" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoint_sg.id
  security_group_id        = aws_security_group.lambda_sg.id
  description              = "HTTPS to VPC Endpoints"
}

# VPC Endpoint for EC2 API
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.environment}-snapshot-cleanup-ec2-endpoint"
  }
}

# VPC Endpoint for CloudWatch Logs (required for Lambda to write logs)
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.environment}-snapshot-cleanup-logs-endpoint"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${var.environment}-${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.environment}-${var.lambda_function_name}-role"
  }
}

# IAM Policy for Lambda to access EC2
resource "aws_iam_role_policy" "lambda_ec2" {
  name = "${var.environment}-${var.lambda_function_name}-ec2-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeTags",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for Lambda VPC access
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# IAM Policy for Lambda CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.environment}-${var.lambda_function_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.environment}-${var.lambda_function_name}-logs"
  }
}

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../lambda/lambda_package.zip"
}

# Lambda Function
resource "aws_lambda_function" "snapshot_cleanup" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.environment}-${var.lambda_function_name}"
  role            = aws_iam_role.lambda_exec.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 256

  environment {
    variables = {
      RETENTION_DAYS   = var.snapshot_retention_days
      EXCLUDE_TAG_KEY  = var.exclude_tag_key
      EXCLUDE_TAG_VALUE = var.exclude_tag_value
      REGION       = var.aws_region
    }
  }

  # VPC Configuration
  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda_logs,
  ]

  tags = {
    Name = "${var.environment}-${var.lambda_function_name}"
  }
}

# EventBridge Rule (CloudWatch Events)
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.environment}-${var.lambda_function_name}-daily-trigger"
  description         = "Trigger Lambda function daily to clean up old snapshots"
  schedule_expression = var.schedule_expression

  tags = {
    Name = "${var.environment}-${var.lambda_function_name}-daily-trigger"
  }
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "${var.environment}-${var.lambda_function_name}-target"
  arn       = aws_lambda_function.snapshot_cleanup.arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}


