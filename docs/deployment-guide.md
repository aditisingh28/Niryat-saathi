# Deployment Guide for NiryatSaathi

This guide provides step-by-step instructions for deploying the NiryatSaathi application to AWS.

## Prerequisites

Before starting deployment, ensure you have completed:
- [AWS Setup Guide](aws-setup.md) - All AWS services enabled and configured
- AWS CLI installed and configured
- Python 3.11+ installed
- Node.js 18+ and npm installed
- Git repository cloned

## Deployment Overview

The deployment process consists of 10 phases:

1. **Phase 1**: AWS Infrastructure Setup (DynamoDB, S3, IAM)
2. **Phase 2**: Data Ingestion (HSN codes, test dataset)
3. **Phase 3**: HSN Classifier Lambda
4. **Phase 4**: Document Validation Lambdas
5. **Phase 5**: Step Functions Workflow
6. **Phase 6**: API Gateway Configuration
7. **Phase 7**: Frontend Deployment
8. **Phase 8**: Security Configuration
9. **Phase 9**: Monitoring Setup
10. **Phase 10**: Testing and Validation

---

## Phase 1: AWS Infrastructure Setup

### 1.1 Deploy DynamoDB Tables

```bash
cd niryatsaathi
./scripts/deploy-dynamodb.sh
```

**Manual steps if script fails:**

```bash
# HSNCodeMaster
aws dynamodb create-table \
  --table-name HSNCodeMaster \
  --attribute-definitions AttributeName=HSNCode,AttributeType=S AttributeName=Chapter,AttributeType=S \
  --key-schema AttributeName=HSNCode,KeyType=HASH \
  --global-secondary-indexes file://infrastructure/dynamodb/hsn-gsi.json \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --region ap-south-1

# UserProfiles
aws dynamodb create-table \
  --table-name UserProfiles \
  --attribute-definitions AttributeName=UserID,AttributeType=S \
  --key-schema AttributeName=UserID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --region ap-south-1

# DocumentHistory
aws dynamodb create-table \
  --table-name DocumentHistory \
  --attribute-definitions AttributeName=DocumentID,AttributeType=S \
  --key-schema AttributeName=DocumentID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --region ap-south-1

aws dynamodb update-time-to-live \
  --table-name DocumentHistory \
  --time-to-live-specification "Enabled=true, AttributeName=TTL" \
  --region ap-south-1

# AuditLog
aws dynamodb create-table \
  --table-name AuditLog \
  --attribute-definitions AttributeName=LogID,AttributeType=S AttributeName=Timestamp,AttributeType=S \
  --key-schema AttributeName=LogID,KeyType=HASH \
  --global-secondary-indexes file://infrastructure/dynamodb/audit-gsi.json \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --region ap-south-1
```

**Verify:**
```bash
aws dynamodb list-tables --region ap-south-1
```

### 1.2 Deploy S3 Buckets

```bash
./scripts/deploy-s3.sh
```

**Manual steps:**

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="niryatsaathi-documents-${ACCOUNT_ID}"

# Create bucket
aws s3api create-bucket \
  --bucket ${BUCKET_NAME} \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration file://infrastructure/s3/encryption-config.json

# Block public access
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Set lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
  --bucket ${BUCKET_NAME} \
  --lifecycle-configuration file://infrastructure/s3/lifecycle-policy.json

# Create folders
aws s3api put-object --bucket ${BUCKET_NAME} --key documents/
aws s3api put-object --bucket ${BUCKET_NAME} --key policies/
aws s3api put-object --bucket ${BUCKET_NAME} --key hsn-data/
```

**Verify:**
```bash
aws s3 ls
aws s3 ls s3://${BUCKET_NAME}/
```

---

## Phase 2: Data Ingestion

### 2.1 Download HSN Code Master Data

```bash
./scripts/download-hsn-data.sh
```

This script downloads the CBIC HSN code master list from the official source.

**Manual download:**
1. Visit: https://www.cbic.gov.in/resources//htdocs-cbec/customs/cs-act/notifications/notfns-2017/cs-tarr2017/cs-tarr2017-annexure.pdf
2. Extract HSN codes to CSV format
3. Save as `data/hsn-master.csv`

### 2.2 Deploy HSN Data Loader Lambda

```bash
cd lambda/hsn-data-loader

# Install dependencies
pip install -r requirements.txt -t package/
cp lambda_function.py package/

# Create deployment package
cd package
zip -r ../hsn-data-loader.zip .
cd ..

# Deploy Lambda
aws lambda create-function \
  --function-name HSNDataLoader \
  --runtime python3.11 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/NiryatSaathi-DataLoader-Role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://hsn-data-loader.zip \
  --timeout 300 \
  --memory-size 512 \
  --environment Variables={DYNAMODB_TABLE=HSNCodeMaster,S3_BUCKET=${BUCKET_NAME}} \
  --region ap-south-1
```

### 2.3 Upload HSN Data to S3

```bash
aws s3 cp data/hsn-master.csv s3://${BUCKET_NAME}/hsn-data/hsn-master.csv
```

### 2.4 Load HSN Data into DynamoDB

```bash
aws lambda invoke \
  --function-name HSNDataLoader \
  --region ap-south-1 \
  --payload '{"action": "load_hsn_data"}' \
  response.json

cat response.json
```

**Expected output:**
```json
{
  "statusCode": 200,
  "message": "Successfully loaded 21000 HSN codes",
  "records_loaded": 21000
}
```

### 2.5 Create Test Dataset

```bash
# Upload test dataset
aws s3 cp test-data/hsn-test-products.json s3://${BUCKET_NAME}/hsn-data/test-products.json
aws s3 cp test-data/ground-truth.json s3://${BUCKET_NAME}/hsn-data/ground-truth.json
```

---

## Phase 3: HSN Classifier Lambda

### 3.1 Build and Deploy HSNClassifier

```bash
cd lambda/hsn-classifier

# Install dependencies
pip install -r requirements.txt -t package/
cp lambda_function.py package/

# Create deployment package
cd package
zip -r ../hsn-classifier.zip .
cd ..

# Deploy Lambda
aws lambda create-function \
  --function-name HSNClassifier \
  --runtime python3.11 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/NiryatSaathi-HSNClassifier-Role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://hsn-classifier.zip \
  --timeout 30 \
  --memory-size 512 \
  --environment Variables='{
    "BEDROCK_MODEL_ID":"anthropic.claude-sonnet-4-5",
    "DYNAMODB_HSN_TABLE":"HSNCodeMaster",
    "DYNAMODB_AUDIT_TABLE":"AuditLog",
    "AWS_REGION":"ap-south-1"
  }' \
  --region ap-south-1
```

### 3.2 Test HSNClassifier

```bash
aws lambda invoke \
  --function-name HSNClassifier \
  --region ap-south-1 \
  --payload '{
    "body": "{\"product_description\":\"handmade turmeric soap\",\"language\":\"en\",\"user_id\":\"test_user\"}"
  }' \
  response.json

cat response.json
```

**Expected output:**
```json
{
  "statusCode": 200,
  "body": "{\"hsn_codes\":[{\"code\":\"34011190\",\"confidence\":0.89,...}]}"
}
```

---

## Phase 4: Document Validation Lambdas

### 4.1 Deploy DocumentProcessor Lambda

```bash
cd lambda/document-processor

pip install -r requirements.txt -t package/
cp lambda_function.py package/
cd package
zip -r ../document-processor.zip .
cd ..

aws lambda create-function \
  --function-name DocumentProcessor \
  --runtime python3.11 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/NiryatSaathi-DocumentProcessor-Role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://document-processor.zip \
  --timeout 60 \
  --memory-size 1024 \
  --environment Variables='{
    "S3_BUCKET":"'${BUCKET_NAME}'",
    "AWS_REGION":"ap-south-1"
  }' \
  --region ap-south-1
```

### 4.2 Deploy DocumentValidator Lambda

```bash
cd lambda/document-validator

pip install -r requirements.txt -t package/
cp lambda_function.py package/
cd package
zip -r ../document-validator.zip .
cd ..

aws lambda create-function \
  --function-name DocumentValidator \
  --runtime python3.11 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/NiryatSaathi-DocumentValidator-Role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://document-validator.zip \
  --timeout 30 \
  --memory-size 512 \
  --environment Variables='{
    "BEDROCK_MODEL_ID":"anthropic.claude-sonnet-4-5",
    "DYNAMODB_HISTORY_TABLE":"DocumentHistory",
    "AWS_REGION":"ap-south-1"
  }' \
  --region ap-south-1
```

### 4.3 Test Document Processing

```bash
# Upload test invoice
aws s3 cp test-data/sample-invoices/invoice-001.pdf s3://${BUCKET_NAME}/documents/test/invoice-001.pdf

# Test DocumentProcessor
aws lambda invoke \
  --function-name DocumentProcessor \
  --region ap-south-1 \
  --payload '{
    "bucket":"'${BUCKET_NAME}'",
    "key":"documents/test/invoice-001.pdf"
  }' \
  response.json

cat response.json
```

---

## Phase 5: Step Functions Workflow

### 5.1 Create Step Functions State Machine

```bash
# Create IAM role for Step Functions
aws iam create-role \
  --role-name NiryatSaathi-StepFunctions-Role \
  --assume-role-policy-document file://infrastructure/iam/stepfunctions-trust-policy.json

aws iam put-role-policy \
  --role-name NiryatSaathi-StepFunctions-Role \
  --policy-name LambdaInvokePolicy \
  --policy-document file://infrastructure/iam/stepfunctions-lambda-policy.json

# Create state machine
aws stepfunctions create-state-machine \
  --name DocumentValidationWorkflow \
  --definition file://infrastructure/step-functions/document-workflow.json \
  --role-arn arn:aws:iam::${ACCOUNT_ID}:role/NiryatSaathi-StepFunctions-Role \
  --region ap-south-1
```

### 5.2 Test Step Functions Workflow

```bash
STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines --query 'stateMachines[?name==`DocumentValidationWorkflow`].stateMachineArn' --output text --region ap-south-1)

aws stepfunctions start-execution \
  --state-machine-arn ${STATE_MACHINE_ARN} \
  --input '{
    "bucket":"'${BUCKET_NAME}'",
    "key":"documents/test/invoice-001.pdf",
    "user_id":"test_user"
  }' \
  --region ap-south-1
```

---

## Phase 6: API Gateway Configuration

### 6.1 Create REST API

```bash
# Create API
API_ID=$(aws apigateway create-rest-api \
  --name "NiryatSaathi-API" \
  --description "API for NiryatSaathi export compliance assistant" \
  --endpoint-configuration types=REGIONAL \
  --region ap-south-1 \
  --query 'id' \
  --output text)

echo "API ID: ${API_ID}"
```

### 6.2 Create Resources and Methods

```bash
# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id ${API_ID} \
  --region ap-south-1 \
  --query 'items[?path==`/`].id' \
  --output text)

# Create /api resource
API_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id ${API_ID} \
  --parent-id ${ROOT_ID} \
  --path-part api \
  --region ap-south-1 \
  --query 'id' \
  --output text)

# Create /api/v1 resource
V1_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id ${API_ID} \
  --parent-id ${API_RESOURCE_ID} \
  --path-part v1 \
  --region ap-south-1 \
  --query 'id' \
  --output text)

# Create /api/v1/classify-product resource
CLASSIFY_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id ${API_ID} \
  --parent-id ${V1_RESOURCE_ID} \
  --path-part classify-product \
  --region ap-south-1 \
  --query 'id' \
  --output text)

# Create POST method for classify-product
aws apigateway put-method \
  --rest-api-id ${API_ID} \
  --resource-id ${CLASSIFY_RESOURCE_ID} \
  --http-method POST \
  --authorization-type NONE \
  --region ap-south-1

# Integrate with HSNClassifier Lambda
HSN_LAMBDA_ARN=$(aws lambda get-function --function-name HSNClassifier --region ap-south-1 --query 'Configuration.FunctionArn' --output text)

aws apigateway put-integration \
  --rest-api-id ${API_ID} \
  --resource-id ${CLASSIFY_RESOURCE_ID} \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:ap-south-1:lambda:path/2015-03-31/functions/${HSN_LAMBDA_ARN}/invocations \
  --region ap-south-1

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
  --function-name HSNClassifier \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:ap-south-1:${ACCOUNT_ID}:${API_ID}/*/*" \
  --region ap-south-1
```

### 6.3 Enable CORS

```bash
# Add OPTIONS method for CORS
aws apigateway put-method \
  --rest-api-id ${API_ID} \
  --resource-id ${CLASSIFY_RESOURCE_ID} \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region ap-south-1

aws apigateway put-integration \
  --rest-api-id ${API_ID} \
  --resource-id ${CLASSIFY_RESOURCE_ID} \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
  --region ap-south-1

aws apigateway put-method-response \
  --rest-api-id ${API_ID} \
  --resource-id ${CLASSIFY_RESOURCE_ID} \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers":false,
    "method.response.header.Access-Control-Allow-Methods":false,
    "method.response.header.Access-Control-Allow-Origin":false
  }' \
  --region ap-south-1

aws apigateway put-integration-response \
  --rest-api-id ${API_ID} \
  --resource-id ${CLASSIFY_RESOURCE_ID} \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers":"'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'",
    "method.response.header.Access-Control-Allow-Methods":"'"'"'POST,OPTIONS'"'"'",
    "method.response.header.Access-Control-Allow-Origin":"'"'"'*'"'"'"
  }' \
  --region ap-south-1
```

### 6.4 Deploy API

```bash
# Create deployment
aws apigateway create-deployment \
  --rest-api-id ${API_ID} \
  --stage-name prod \
  --stage-description "Production stage" \
  --description "Initial deployment" \
  --region ap-south-1

# Get API endpoint
API_ENDPOINT="https://${API_ID}.execute-api.ap-south-1.amazonaws.com/prod"
echo "API Endpoint: ${API_ENDPOINT}"
```

### 6.5 Test API

```bash
curl -X POST ${API_ENDPOINT}/api/v1/classify-product \
  -H "Content-Type: application/json" \
  -d '{
    "product_description": "handmade turmeric soap",
    "language": "en",
    "user_id": "test_user"
  }'
```

---

## Phase 7: Frontend Deployment

### 7.1 Build React Frontend

```bash
cd frontend

# Install dependencies
npm install

# Update API endpoint in .env
echo "REACT_APP_API_ENDPOINT=${API_ENDPOINT}" > .env.production

# Build production bundle
npm run build
```

### 7.2 Create S3 Bucket for Frontend

```bash
FRONTEND_BUCKET="niryatsaathi-frontend-${ACCOUNT_ID}"

aws s3api create-bucket \
  --bucket ${FRONTEND_BUCKET} \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Configure for static website hosting
aws s3 website s3://${FRONTEND_BUCKET}/ \
  --index-document index.html \
  --error-document index.html
```

### 7.3 Upload Frontend Files

```bash
aws s3 sync build/ s3://${FRONTEND_BUCKET}/ --delete
```

### 7.4 Create CloudFront Distribution

```bash
aws cloudfront create-distribution \
  --origin-domain-name ${FRONTEND_BUCKET}.s3.ap-south-1.amazonaws.com \
  --default-root-object index.html \
  --region ap-south-1
```

**Note:** CloudFront distribution creation takes 15-20 minutes.

### 7.5 Get CloudFront URL

```bash
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query 'DistributionList.Items[0].Id' --output text)
CLOUDFRONT_URL=$(aws cloudfront get-distribution --id ${DISTRIBUTION_ID} --query 'Distribution.DomainName' --output text)

echo "Frontend URL: https://${CLOUDFRONT_URL}"
```

---

## Phase 8: Security Configuration

### 8.1 Verify Encryption

```bash
# Check DynamoDB encryption
aws dynamodb describe-table --table-name HSNCodeMaster --region ap-south-1 --query 'Table.SSEDescription'

# Check S3 encryption
aws s3api get-bucket-encryption --bucket ${BUCKET_NAME}
```

### 8.2 Verify Public Access Blocks

```bash
aws s3api get-public-access-block --bucket ${BUCKET_NAME}
```

### 8.3 Review IAM Policies

```bash
aws iam get-role-policy --role-name NiryatSaathi-HSNClassifier-Role --policy-name BedrockAccess
```

---

## Phase 9: Monitoring Setup

### 9.1 Create CloudWatch Dashboard

```bash
aws cloudwatch put-dashboard \
  --dashboard-name NiryatSaathi-Dashboard \
  --dashboard-body file://infrastructure/cloudwatch/dashboard.json \
  --region ap-south-1
```

### 9.2 Create CloudWatch Alarms

```bash
# Lambda error alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "HSNClassifier-Errors" \
  --alarm-description "Alert when HSNClassifier error rate exceeds 5%" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=HSNClassifier \
  --region ap-south-1

# API Gateway 5xx alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "API-5xx-Errors" \
  --alarm-description "Alert when API 5xx rate exceeds 1%" \
  --metric-name 5XXError \
  --namespace AWS/ApiGateway \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ApiName,Value=NiryatSaathi-API \
  --region ap-south-1
```

---

## Phase 10: Testing and Validation

### 10.1 Test HSN Classification

```bash
python scripts/test-hsn-accuracy.py
```

**Expected output:**
```
Testing 20 products...
Accuracy: 85% (17/20 correct)
Average confidence: 0.82
Average response time: 3.2 seconds
```

### 10.2 Test Document Validation

```bash
python scripts/test-document-validator.py
```

### 10.3 End-to-End Test

```bash
# Open frontend in browser
open https://${CLOUDFRONT_URL}

# Test HSN classification
# Test document upload
# Verify results
```

---

## Deployment Checklist

- [ ] All DynamoDB tables created and encrypted
- [ ] S3 buckets created with lifecycle policies
- [ ] HSN data loaded into DynamoDB (~21,000 codes)
- [ ] HSNClassifier Lambda deployed and tested
- [ ] DocumentProcessor Lambda deployed and tested
- [ ] DocumentValidator Lambda deployed and tested
- [ ] Step Functions workflow created and tested
- [ ] API Gateway deployed with CORS enabled
- [ ] Frontend built and deployed to S3
- [ ] CloudFront distribution created
- [ ] CloudWatch dashboard and alarms configured
- [ ] Security configurations verified
- [ ] End-to-end testing completed

---

## Rollback Procedures

### Rollback Lambda Function

```bash
# List versions
aws lambda list-versions-by-function --function-name HSNClassifier --region ap-south-1

# Update alias to previous version
aws lambda update-alias \
  --function-name HSNClassifier \
  --name prod \
  --function-version 1 \
  --region ap-south-1
```

### Rollback Frontend

```bash
# Restore previous S3 version
aws s3 sync s3://${FRONTEND_BUCKET}-backup/ s3://${FRONTEND_BUCKET}/ --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/*"
```

---

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.

---

## Next Steps

After successful deployment:
1. Monitor CloudWatch metrics
2. Review audit logs
3. Optimize Lambda memory allocation
4. Implement caching for frequently requested HSN codes
5. Add custom domain name
6. Set up CI/CD pipeline

---

## Support

For deployment issues:
- Check CloudWatch logs
- Review IAM permissions
- Verify service quotas
- Contact AWS Support if needed
