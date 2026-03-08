# AWS Setup Guide for NiryatSaathi

This guide walks you through setting up all required AWS services for the NiryatSaathi application.

## Table of Contents

1. [AWS Account Setup](#aws-account-setup)
2. [Enable Amazon Bedrock](#enable-amazon-bedrock)
3. [Enable Amazon Textract](#enable-amazon-textract)
4. [Configure IAM Roles](#configure-iam-roles)
5. [Set Up AWS CLI](#set-up-aws-cli)
6. [Create DynamoDB Tables](#create-dynamodb-tables)
7. [Create S3 Buckets](#create-s3-buckets)
8. [Set Up API Gateway](#set-up-api-gateway)
9. [Configure Secrets Manager](#configure-secrets-manager)
10. [Set Up CloudWatch](#set-up-cloudwatch)

---

## 1. AWS Account Setup

### Prerequisites
- Valid email address
- Credit/debit card for verification
- Phone number for verification

### Steps

1. **Create AWS Account**
   - Go to https://aws.amazon.com
   - Click "Create an AWS Account"
   - Follow the registration process
   - Choose "Basic Support" plan (free)

2. **Set Default Region to Mumbai**
   - Sign in to AWS Console
   - Click region dropdown (top right)
   - Select "Asia Pacific (Mumbai) ap-south-1"

3. **Enable Billing Alerts**
   ```bash
   # Set up billing alert for ₹1,000
   aws cloudwatch put-metric-alarm \
     --alarm-name "NiryatSaathi-Cost-Alert" \
     --alarm-description "Alert when estimated charges exceed ₹1000" \
     --metric-name EstimatedCharges \
     --namespace AWS/Billing \
     --statistic Maximum \
     --period 21600 \
     --evaluation-periods 1 \
     --threshold 1000 \
     --comparison-operator GreaterThanThreshold \
     --region us-east-1
   ```

---

## 2. Enable Amazon Bedrock

### Request Model Access

1. **Navigate to Bedrock Console**
   - Go to AWS Console
   - Search for "Bedrock"
   - Click "Amazon Bedrock"

2. **Request Claude Sonnet 4.5 Access**
   - Click "Model access" in left sidebar
   - Click "Request model access"
   - Find "Anthropic" section
   - Check "Claude Sonnet 4.5"
   - Click "Request model access"
   - Fill out use case form:
     - Use case: "Export compliance assistant for Indian MSMEs"
     - Expected usage: "HSN code classification and document validation"
   - Submit request

3. **Wait for Approval**
   - Approval typically takes 1-2 hours
   - You'll receive email notification
   - Check status in Bedrock console

4. **Verify Access**
   ```bash
   aws bedrock list-foundation-models \
     --region ap-south-1 \
     --query 'modelSummaries[?contains(modelId, `claude-sonnet-4-5`)]'
   ```

### Bedrock Pricing
- Input: $3 per 1M tokens (~₹250)
- Output: $15 per 1M tokens (~₹1,250)
- Estimated hackathon cost: ~₹500 for 100K tokens

---

## 3. Enable Amazon Textract

### Enable Service

1. **Navigate to Textract Console**
   - Go to AWS Console
   - Search for "Textract"
   - Click "Amazon Textract"

2. **No Explicit Enablement Required**
   - Textract is available by default
   - Just need IAM permissions

3. **Verify Access**
   ```bash
   aws textract detect-document-text \
     --document '{"S3Object":{"Bucket":"test-bucket","Name":"test.jpg"}}' \
     --region ap-south-1
   ```

### Textract Pricing
- Free tier: 1,000 pages/month for first 3 months
- After: $1.50 per 1,000 pages (~₹125)
- Estimated hackathon cost: Free (within tier)

---

## 4. Configure IAM Roles

### Create Lambda Execution Roles

#### HSNClassifier Role

1. **Create Role**
   ```bash
   aws iam create-role \
     --role-name NiryatSaathi-HSNClassifier-Role \
     --assume-role-policy-document file://infrastructure/iam/lambda-trust-policy.json \
     --region ap-south-1
   ```

2. **Attach Policies**
   ```bash
   # Bedrock access
   aws iam put-role-policy \
     --role-name NiryatSaathi-HSNClassifier-Role \
     --policy-name BedrockAccess \
     --policy-document file://infrastructure/iam/bedrock-policy.json

   # DynamoDB access
   aws iam put-role-policy \
     --role-name NiryatSaathi-HSNClassifier-Role \
     --policy-name DynamoDBAccess \
     --policy-document file://infrastructure/iam/dynamodb-hsn-policy.json

   # Translate access
   aws iam put-role-policy \
     --role-name NiryatSaathi-HSNClassifier-Role \
     --policy-name TranslateAccess \
     --policy-document file://infrastructure/iam/translate-policy.json

   # CloudWatch Logs
   aws iam attach-role-policy \
     --role-name NiryatSaathi-HSNClassifier-Role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   ```

#### DocumentProcessor Role

```bash
aws iam create-role \
  --role-name NiryatSaathi-DocumentProcessor-Role \
  --assume-role-policy-document file://infrastructure/iam/lambda-trust-policy.json

aws iam put-role-policy \
  --role-name NiryatSaathi-DocumentProcessor-Role \
  --policy-name TextractAccess \
  --policy-document file://infrastructure/iam/textract-policy.json

aws iam put-role-policy \
  --role-name NiryatSaathi-DocumentProcessor-Role \
  --policy-name S3Access \
  --policy-document file://infrastructure/iam/s3-read-policy.json

aws iam attach-role-policy \
  --role-name NiryatSaathi-DocumentProcessor-Role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

#### DocumentValidator Role

```bash
aws iam create-role \
  --role-name NiryatSaathi-DocumentValidator-Role \
  --assume-role-policy-document file://infrastructure/iam/lambda-trust-policy.json

aws iam put-role-policy \
  --role-name NiryatSaathi-DocumentValidator-Role \
  --policy-name BedrockAccess \
  --policy-document file://infrastructure/iam/bedrock-policy.json

aws iam put-role-policy \
  --role-name NiryatSaathi-DocumentValidator-Role \
  --policy-name DynamoDBAccess \
  --policy-document file://infrastructure/iam/dynamodb-doc-policy.json

aws iam attach-role-policy \
  --role-name NiryatSaathi-DocumentValidator-Role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### IAM Policy Files

Create these policy files in `infrastructure/iam/`:

**lambda-trust-policy.json**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**bedrock-policy.json**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": "arn:aws:bedrock:ap-south-1::foundation-model/anthropic.claude-sonnet-4-5"
    }
  ]
}
```

**textract-policy.json**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "textract:AnalyzeDocument",
        "textract:DetectDocumentText"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 5. Set Up AWS CLI

### Install AWS CLI

**macOS**
```bash
brew install awscli
```

**Linux**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Windows**
```powershell
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

### Configure Credentials

1. **Create IAM User for CLI**
   - Go to IAM Console
   - Click "Users" → "Add users"
   - Username: `niryatsaathi-cli`
   - Access type: "Programmatic access"
   - Attach policy: "AdministratorAccess" (for development)
   - Save Access Key ID and Secret Access Key

2. **Configure AWS CLI**
   ```bash
   aws configure
   # AWS Access Key ID: [your-access-key]
   # AWS Secret Access Key: [your-secret-key]
   # Default region name: ap-south-1
   # Default output format: json
   ```

3. **Verify Configuration**
   ```bash
   aws sts get-caller-identity
   aws s3 ls
   ```

---

## 6. Create DynamoDB Tables

### HSNCodeMaster Table

```bash
aws dynamodb create-table \
  --table-name HSNCodeMaster \
  --attribute-definitions \
    AttributeName=HSNCode,AttributeType=S \
    AttributeName=Chapter,AttributeType=S \
  --key-schema \
    AttributeName=HSNCode,KeyType=HASH \
  --global-secondary-indexes \
    '[{
      "IndexName": "ChapterIndex",
      "KeySchema": [{"AttributeName":"Chapter","KeyType":"HASH"}],
      "Projection": {"ProjectionType":"ALL"},
      "ProvisionedThroughput": {"ReadCapacityUnits":5,"WriteCapacityUnits":5}
    }]' \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --region ap-south-1
```

### UserProfiles Table

```bash
aws dynamodb create-table \
  --table-name UserProfiles \
  --attribute-definitions \
    AttributeName=UserID,AttributeType=S \
  --key-schema \
    AttributeName=UserID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --region ap-south-1
```

### DocumentHistory Table

```bash
aws dynamodb create-table \
  --table-name DocumentHistory \
  --attribute-definitions \
    AttributeName=DocumentID,AttributeType=S \
  --key-schema \
    AttributeName=DocumentID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --region ap-south-1

# Enable TTL
aws dynamodb update-time-to-live \
  --table-name DocumentHistory \
  --time-to-live-specification "Enabled=true, AttributeName=TTL" \
  --region ap-south-1
```

### AuditLog Table

```bash
aws dynamodb create-table \
  --table-name AuditLog \
  --attribute-definitions \
    AttributeName=LogID,AttributeType=S \
    AttributeName=Timestamp,AttributeType=S \
  --key-schema \
    AttributeName=LogID,KeyType=HASH \
  --global-secondary-indexes \
    '[{
      "IndexName": "TimestampIndex",
      "KeySchema": [{"AttributeName":"Timestamp","KeyType":"HASH"}],
      "Projection": {"ProjectionType":"ALL"},
      "ProvisionedThroughput": {"ReadCapacityUnits":5,"WriteCapacityUnits":5}
    }]' \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --region ap-south-1
```

### Verify Tables

```bash
aws dynamodb list-tables --region ap-south-1
aws dynamodb describe-table --table-name HSNCodeMaster --region ap-south-1
```

---

## 7. Create S3 Buckets

### Create Documents Bucket

```bash
# Replace ACCOUNT_ID with your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="niryatsaathi-documents-${ACCOUNT_ID}"

aws s3api create-bucket \
  --bucket ${BUCKET_NAME} \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Set lifecycle policy (30-day deletion)
aws s3api put-bucket-lifecycle-configuration \
  --bucket ${BUCKET_NAME} \
  --lifecycle-configuration file://infrastructure/s3/lifecycle-policy.json
```

**lifecycle-policy.json**
```json
{
  "Rules": [
    {
      "Id": "Delete-After-30-Days",
      "Status": "Enabled",
      "Prefix": "documents/",
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
```

### Create Folder Structure

```bash
aws s3api put-object --bucket ${BUCKET_NAME} --key documents/
aws s3api put-object --bucket ${BUCKET_NAME} --key policies/
aws s3api put-object --bucket ${BUCKET_NAME} --key hsn-data/
```

---

## 8. Set Up API Gateway

### Create REST API

```bash
aws apigateway create-rest-api \
  --name "NiryatSaathi-API" \
  --description "API for NiryatSaathi export compliance assistant" \
  --endpoint-configuration types=REGIONAL \
  --region ap-south-1
```

### Enable CORS

```bash
# Get API ID
API_ID=$(aws apigateway get-rest-apis --query 'items[?name==`NiryatSaathi-API`].id' --output text --region ap-south-1)

# Enable CORS (will be configured during deployment)
```

### Configure Rate Limiting

```bash
# Create usage plan
aws apigateway create-usage-plan \
  --name "NiryatSaathi-Standard-Plan" \
  --description "100 requests per minute" \
  --throttle burstLimit=100,rateLimit=100 \
  --region ap-south-1
```

---

## 9. Configure Secrets Manager

### Store API Keys (if needed)

```bash
# Example: Store third-party API key
aws secretsmanager create-secret \
  --name NiryatSaathi/APIKeys \
  --description "API keys for NiryatSaathi" \
  --secret-string '{"example_key":"example_value"}' \
  --region ap-south-1
```

---

## 10. Set Up CloudWatch

### Create Log Groups

```bash
aws logs create-log-group \
  --log-group-name /aws/lambda/HSNClassifier \
  --region ap-south-1

aws logs create-log-group \
  --log-group-name /aws/lambda/DocumentProcessor \
  --region ap-south-1

aws logs create-log-group \
  --log-group-name /aws/lambda/DocumentValidator \
  --region ap-south-1

aws logs create-log-group \
  --log-group-name /aws/apigateway/NiryatSaathi-API \
  --region ap-south-1
```

### Set Log Retention

```bash
aws logs put-retention-policy \
  --log-group-name /aws/lambda/HSNClassifier \
  --retention-in-days 7 \
  --region ap-south-1
```

### Create CloudWatch Dashboard

```bash
aws cloudwatch put-dashboard \
  --dashboard-name NiryatSaathi-Dashboard \
  --dashboard-body file://infrastructure/cloudwatch/dashboard.json \
  --region ap-south-1
```

---

## Verification Checklist

- [ ] AWS account created and Mumbai region selected
- [ ] Amazon Bedrock enabled with Claude Sonnet 4.5 access
- [ ] Amazon Textract accessible
- [ ] IAM roles created for all Lambda functions
- [ ] AWS CLI installed and configured
- [ ] All 4 DynamoDB tables created with encryption
- [ ] S3 bucket created with encryption and lifecycle policy
- [ ] API Gateway REST API created
- [ ] Secrets Manager configured
- [ ] CloudWatch log groups created

---

## Next Steps

After completing this setup:
1. Deploy Lambda functions - see [deployment-guide.md](deployment-guide.md)
2. Load HSN data into DynamoDB
3. Deploy frontend to S3/CloudFront
4. Test end-to-end functionality

---

## Troubleshooting

### Bedrock Access Denied
- Verify model access request is approved
- Check IAM role has `bedrock:InvokeModel` permission
- Ensure using correct model ID: `anthropic.claude-sonnet-4-5`

### DynamoDB Table Creation Fails
- Check if table already exists
- Verify IAM permissions
- Ensure region is ap-south-1

### S3 Bucket Name Conflict
- Bucket names must be globally unique
- Add account ID or random suffix to bucket name

### CLI Commands Fail
- Run `aws configure` to verify credentials
- Check IAM user has sufficient permissions
- Verify region is set to ap-south-1

---

## Cost Monitoring

Set up billing alerts:

```bash
# Create SNS topic for alerts
aws sns create-topic --name NiryatSaathi-Billing-Alerts --region ap-south-1

# Subscribe email
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-south-1:ACCOUNT_ID:NiryatSaathi-Billing-Alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

---

## Security Best Practices

1. **Never commit AWS credentials to Git**
   - Add `.aws/` to `.gitignore`
   - Use environment variables or AWS CLI profiles

2. **Use least privilege IAM policies**
   - Grant only necessary permissions
   - Review policies regularly

3. **Enable MFA on root account**
   - Go to IAM → Security credentials
   - Enable virtual MFA device

4. **Rotate access keys regularly**
   - Rotate every 90 days
   - Delete unused keys

5. **Monitor CloudTrail logs**
   - Enable CloudTrail for audit logging
   - Review logs for suspicious activity

---

For more information, see:
- [AWS Documentation](https://docs.aws.amazon.com/)
- [Amazon Bedrock User Guide](https://docs.aws.amazon.com/bedrock/)
- [Amazon Textract Developer Guide](https://docs.aws.amazon.com/textract/)
