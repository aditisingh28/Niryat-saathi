#!/bin/bash

# Complete setup script for NiryatSaathi
# This script automates the entire deployment process
# Usage: ./scripts/setup-all.sh

set -e

REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="niryatsaathi-documents-${ACCOUNT_ID}"

echo "========================================="
echo "NiryatSaathi Complete Setup"
echo "========================================="
echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"
echo "Bucket: $BUCKET_NAME"
echo ""
echo "This script will:"
echo "1. Create DynamoDB tables"
echo "2. Create S3 bucket"
echo "3. Create IAM roles"
echo "4. Deploy Lambda functions"
echo "5. Load HSN data"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 1: Create DynamoDB tables
echo ""
echo "========================================="
echo "Step 1: Creating DynamoDB Tables"
echo "========================================="
echo ""

create_table() {
    local TABLE_NAME=$1
    echo "Creating table: $TABLE_NAME..."
    
    if aws dynamodb describe-table --table-name $TABLE_NAME --region $REGION 2>/dev/null; then
        echo "✓ Table $TABLE_NAME already exists"
    else
        case $TABLE_NAME in
            "HSNCodeMaster")
                aws dynamodb create-table \
                    --table-name HSNCodeMaster \
                    --attribute-definitions \
                        AttributeName=HSNCode,AttributeType=S \
                        AttributeName=Chapter,AttributeType=S \
                    --key-schema AttributeName=HSNCode,KeyType=HASH \
                    --global-secondary-indexes \
                        '[{"IndexName":"ChapterIndex","KeySchema":[{"AttributeName":"Chapter","KeyType":"HASH"}],"Projection":{"ProjectionType":"ALL"},"ProvisionedThroughput":{"ReadCapacityUnits":5,"WriteCapacityUnits":5}}]' \
                    --billing-mode PAY_PER_REQUEST \
                    --sse-specification Enabled=true \
                    --region $REGION
                ;;
            "UserProfiles")
                aws dynamodb create-table \
                    --table-name UserProfiles \
                    --attribute-definitions AttributeName=UserID,AttributeType=S \
                    --key-schema AttributeName=UserID,KeyType=HASH \
                    --billing-mode PAY_PER_REQUEST \
                    --sse-specification Enabled=true \
                    --region $REGION
                ;;
            "DocumentHistory")
                aws dynamodb create-table \
                    --table-name DocumentHistory \
                    --attribute-definitions AttributeName=DocumentID,AttributeType=S \
                    --key-schema AttributeName=DocumentID,KeyType=HASH \
                    --billing-mode PAY_PER_REQUEST \
                    --sse-specification Enabled=true \
                    --region $REGION
                
                # Enable TTL
                sleep 5
                aws dynamodb update-time-to-live \
                    --table-name DocumentHistory \
                    --time-to-live-specification "Enabled=true, AttributeName=TTL" \
                    --region $REGION
                ;;
            "AuditLog")
                aws dynamodb create-table \
                    --table-name AuditLog \
                    --attribute-definitions \
                        AttributeName=LogID,AttributeType=S \
                        AttributeName=Timestamp,AttributeType=S \
                    --key-schema AttributeName=LogID,KeyType=HASH \
                    --global-secondary-indexes \
                        '[{"IndexName":"TimestampIndex","KeySchema":[{"AttributeName":"Timestamp","KeyType":"HASH"}],"Projection":{"ProjectionType":"ALL"},"ProvisionedThroughput":{"ReadCapacityUnits":5,"WriteCapacityUnits":5}}]' \
                    --billing-mode PAY_PER_REQUEST \
                    --sse-specification Enabled=true \
                    --region $REGION
                ;;
        esac
        echo "✓ Table $TABLE_NAME created"
    fi
}

create_table "HSNCodeMaster"
create_table "UserProfiles"
create_table "DocumentHistory"
create_table "AuditLog"

# Step 2: Create S3 bucket
echo ""
echo "========================================="
echo "Step 2: Creating S3 Bucket"
echo "========================================="
echo ""

if aws s3 ls s3://${BUCKET_NAME} 2>/dev/null; then
    echo "✓ Bucket ${BUCKET_NAME} already exists"
else
    echo "Creating bucket: ${BUCKET_NAME}..."
    aws s3api create-bucket \
        --bucket ${BUCKET_NAME} \
        --region $REGION \
        --create-bucket-configuration LocationConstraint=$REGION
    
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
    
    echo "✓ Bucket ${BUCKET_NAME} created"
fi

# Create folders
aws s3api put-object --bucket ${BUCKET_NAME} --key documents/ || true
aws s3api put-object --bucket ${BUCKET_NAME} --key policies/ || true
aws s3api put-object --bucket ${BUCKET_NAME} --key hsn-data/ || true

echo "✓ S3 bucket configured"

# Step 3: Create IAM roles
echo ""
echo "========================================="
echo "Step 3: Creating IAM Roles"
echo "========================================="
echo ""

./scripts/create-iam-roles.sh

# Wait for IAM roles to propagate
echo "Waiting for IAM roles to propagate (10 seconds)..."
sleep 10

# Step 4: Deploy Lambda functions
echo ""
echo "========================================="
echo "Step 4: Deploying Lambda Functions"
echo "========================================="
echo ""

./scripts/deploy-lambda.sh

# Step 5: Load HSN data
echo ""
echo "========================================="
echo "Step 5: Loading HSN Data"
echo "========================================="
echo ""

./scripts/load-hsn-data.sh

# Final summary
echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "✓ DynamoDB tables created"
echo "✓ S3 bucket created and configured"
echo "✓ IAM roles created"
echo "✓ Lambda functions deployed"
echo "✓ HSN data loaded"
echo ""
echo "Next steps:"
echo "1. Test HSN classifier: ./scripts/test-hsn-classifier.sh"
echo "2. Deploy API Gateway (manual - see docs/deployment-guide.md)"
echo "3. Deploy frontend (manual - see docs/deployment-guide.md)"
echo ""
echo "Important: Make sure you have enabled Amazon Bedrock access"
echo "in the AWS console before testing!"
