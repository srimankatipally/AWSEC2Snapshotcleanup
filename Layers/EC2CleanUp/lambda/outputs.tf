output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.snapshot_cleanup.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.snapshot_cleanup.arn
}

output "lambda_function_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.daily_trigger.arn
}

output "security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}

output "vpc_endpoint_ec2_id" {
  description = "ID of the EC2 VPC Endpoint"
  value       = aws_vpc_endpoint.ec2.id
}

output "vpc_endpoint_cloudwatch_logs_id" {
  description = "ID of the CloudWatch Logs VPC Endpoint"
  value       = aws_vpc_endpoint.cloudwatch_logs.id
}

output "vpc_endpoint_security_group_id" {
  description = "ID of the VPC Endpoint security group"
  value       = aws_security_group.vpc_endpoint_sg.id
}

