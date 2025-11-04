# AWS Lambda EC2 Snapshot Cleanup

Automated solution for cleaning up old EC2 snapshots using AWS Lambda in a VPC with VPC Endpoints. The Lambda function automatically identifies and deletes EC2 snapshots older than a specified retention period (default: 365 days).


## Overview
- **Terraform Infrastructure**: VPC, private subnets, VPC Endpoints, IAM roles, Lambda function, EventBridge rule
- **Lambda Function**: Python 3.11 function that identifies and deletes old EC2 snapshots
- **Automated Scheduling**: EventBridge triggers Lambda on configurable schedule (default: daily at 2 AM UTC)
- **VPC Endpoints**: Private communication with EC2 API and CloudWatch Logs (no internet required)

## Architecture


**Key Components:**
- **VPC**: Private subnets
- **VPC Endpoints**: Interface endpoints for EC2 API and CloudWatch Logs
- **Lambda Function**: Runs in private subnet, accesses AWS services via VPC Endpoints
- **IAM Role**: Least privilege permissions for EC2 operations and logging
- **EventBridge Rule**: Scheduled execution trigger
- **CloudWatch Logs**: Execution logs with 14-day retention

## Prerequisites

1. **AWS Account** with permissions to create:
   - VPCs, subnets, route tables, VPC endpoints
   - IAM roles and policies
   - Lambda functions
   - EventBridge rules
   - CloudWatch log groups

2. **Tools:**
   - AWS CLI configured
   - Terraform >= 1.0
   - Python 3.11 (for local testing)

**Check Permissions:**
```bash
cd terraform
terraform init
terraform plan  # Shows any permission errors
```

## Quick Start


## CI/CD with GitHub Actions

This repository includes GitHub Actions workflows for automated testing and deployment.

### Workflows

1. **Terraform CI/CD** (`.github/workflows/terraform.yml`)
   - **On Pull Requests**: Validates, formats, and plans Terraform changes
   - **On Push to main/master**: Applies Terraform changes automatically
   - Includes security scanning with tfsec

2. **Lambda Function Test** (`.github/workflows/lambda-test.yml`)
   - **On Pull Requests**: Lints and syntax-checks Python code
   - Validates Lambda function code quality

### Setup

1. **Configure GitHub Secrets:**
   - Go to Repository Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`: AWS access key for deployment
     - `AWS_SECRET_ACCESS_KEY`: AWS secret key for deployment

2. **Workflow :**
   - Terraform validation and formatting checks
   - Security scanning with tfsec
   - Automated plan on PRs (commented on PR)
   - Automated apply on merge to main/master
   - Python linting and syntax validation
   - Terraform output artifacts

3. **Manual Workflow Trigger:**
   ```bash
   # Push to trigger workflows
   git push origin main
   ```

### Workflow Behavior

- **Pull Requests**: Runs validation, plan, and linting (no apply)
- **Main/Master Branch**: Runs full validation, plan, and apply
- **Terraform Plan**: Automatically comments on PRs with plan output
- **Security**: tfsec scans for security issues (non-blocking)

## Configuration

### Lambda Environment Variables

- `RETENTION_DAYS`: Snapshot retention period (default: 365)
- `EXCLUDE_TAG_KEY`: Optional tag key to exclude snapshots
- `EXCLUDE_TAG_VALUE`: Optional tag value to exclude snapshots
- `AWS_REGION`: AWS region for snapshots

### Exclude Snapshots from Deletion

Tag snapshots to exclude:
```bash
aws ec2 create-tags \
  --resources snap-1234567890abcdef0 \
  --tags Key=KeepSnapshot,Value=true
```

Configure in `terraform.tfvars`:
```hcl
exclude_tag_key   = "KeepSnapshot"
exclude_tag_value = "true"
```

### Schedule Configuration

EventBridge cron examples:
- `cron(0 2 * * ? *)` - Daily at 2 AM UTC (default)
- `cron(0 0 * * ? *)` - Daily at midnight UTC
- `cron(0 2 ? * MON *)` - Every Monday at 2 AM UTC
- `rate(7 days)` - Every 7 days

## Monitoring

### CloudWatch Logs

View logs:
```bash
aws logs tail /aws/lambda/ec2-snapshot-cleanup --follow
```

**Key Log Messages:**
- `"Found X total snapshots"` - Total snapshots found
- `"Found X snapshots older than Y days"` - Old snapshots identified
- `"Successfully deleted snapshot: snap-xxx"` - Successful deletions
- `"Error deleting snapshot"` - Failed deletions with reasons

### CloudWatch Metrics

Monitor:
- `Invocations` - Function invocation count
- `Errors` - Failed invocations
- `Duration` - Execution time
- `Throttles` - Throttled invocations

**Create Error Alarm:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name lambda-snapshot-cleanup-errors \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=ec2-snapshot-cleanup
```

### CloudWatch Logs Insights Queries

**Count snapshots processed:**
```sql
fields @timestamp, @message
| filter @message like /Found.*snapshots/
| stats count() by bin(5m)
```

**View deletions:**
```sql
fields @timestamp, @message
| filter @message like /Successfully deleted snapshot/
```

## Testing

### Manual Invocation

```bash
aws lambda invoke \
  --function-name ec2-snapshot-cleanup \
  --region us-east-1 \
  response.json
```

### Test with Exclusion Tags

1. Tag a snapshot: `aws ec2 create-tags --resources snap-xxx --tags Key=KeepSnapshot,Value=true`
2. Run Lambda function
3. Verify tagged snapshot is not deleted

### Lambda Cannot Access EC2 API

1. **VPC Configuration:**
   - Verify Lambda in private subnet
   - Verify VPC Endpoints are in "available" state
   - Check route tables (local routes only)

2. **Security Groups:**
   - Lambda SG: Outbound HTTPS (443) to VPC Endpoint SG
   - VPC Endpoint SG: Inbound HTTPS (443) from Lambda SG

3. **VPC Endpoints:**
   - EC2 VPC Endpoint: Available state
   - CloudWatch Logs VPC Endpoint: Available state
   - Both in same subnets as Lambda

4. **IAM Permissions:** Verify Lambda role has `ec2:DescribeSnapshots`, `ec2:DeleteSnapshot`

### Snapshots Not Being Deleted

1. Check CloudWatch Logs for errors
2. Verify IAM permissions: `ec2:DeleteSnapshot`
3. Check snapshot state (some may be in use and cannot be deleted)

### Lambda Function Timing Out

Increase timeout in `terraform/main.tf`:
```hcl
timeout = 600  # 10 minutes
```


```

