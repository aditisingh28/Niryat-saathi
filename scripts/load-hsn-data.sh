#!/bin/bash

# Load HSN data into DynamoDB
# Usage: ./scripts/load-hsn-data.sh

set -e

REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="niryatsaathi-documents-${ACCOUNT_ID}"

echo "========================================="
echo "Loading HSN Data into DynamoDB"
echo "========================================="
echo ""

# Upload sample HSN data to S3
echo "Uploading HSN data to S3..."
aws s3 cp test-data/hsn_master_sample.csv s3://${BUCKET_NAME}/hsn-data/hsn_master.csv --region $REGION

echo "✓ HSN data uploaded to S3"
echo ""

# Invoke HSNDataLoader Lambda
echo "Invoking HSNDataLoader Lambda..."
aws lambda invoke \
    --function-name HSNDataLoader \
    --region $REGION \
    --payload '{"bucket":"'${BUCKET_NAME}'","key":"hsn-data/hsn_master.csv"}' \
    /tmp/hsn-loader-response.json

echo ""
echo "Response:"
cat /tmp/hsn-loader-response.json
echo ""
echo ""

# Verify data load
echo "Verifying data load..."
ITEM_COUNT=$(aws dynamodb scan \
    --table-name HSNCodeMaster \
    --select COUNT \
    --region $REGION \
    --query 'Count' \
    --output text)

echo "✓ HSNCodeMaster table contains $ITEM_COUNT items"
echo ""

# Sample a few items
echo "Sample HSN codes:"
aws dynamodb scan \
    --table-name HSNCodeMaster \
    --limit 3 \
    --region $REGION \
    --query 'Items[*].[HSNCode.S, Description.S]' \
    --output table

echo ""
echo "========================================="
echo "HSN data loaded successfully!"
echo "========================================="
echo ""
echo "Next step: Test HSN classification"
echo "./scripts/test-hsn-classifier.sh"
