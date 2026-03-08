#!/bin/bash

# Update HSNClassifier Lambda environment variables
# Usage: ./scripts/update-hsn-model.sh

set -e

REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
FUNCTION_NAME="HSNClassifier"

echo "========================================="
echo "Updating HSNClassifier Model Configuration"
echo "========================================="
echo "Region: $REGION"
echo "Function: $FUNCTION_NAME"
echo ""

# Update environment variables
echo "Updating environment variables..."
aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --region $REGION \
    --environment Variables="{
        BEDROCK_MODEL_ID=apac.anthropic.claude-3-5-sonnet-20240620-v1:0,
        HSN_TABLE_NAME=HSNCodeMaster,
        AUDIT_TABLE_NAME=AuditLog
    }"

echo ""
echo "✓ HSNClassifier model configuration updated successfully!"
echo ""
echo "New model: apac.anthropic.claude-3-5-sonnet-20240620-v1:0"
