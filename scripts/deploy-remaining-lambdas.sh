#!/bin/bash

# Deploy remaining Lambda functions (skip HSNClassifier)
# Usage: ./scripts/deploy-remaining-lambdas.sh

set -e

# Get script directory and change to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "========================================="
echo "Deploying Remaining Lambda Functions"
echo "========================================="
echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"
echo ""

# Function to deploy a Lambda function
deploy_lambda() {
    local FUNCTION_NAME=$1
    local FUNCTION_DIR=$2
    local ROLE_NAME=$3
    local HANDLER=$4
    local MEMORY=$5
    local TIMEOUT=$6
    
    echo "Deploying $FUNCTION_NAME..."
    
    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "")
    
    if [ -z "$ROLE_ARN" ]; then
        echo "Error: IAM role $ROLE_NAME not found. Please create it first."
        exit 1
    fi
    
    # Create deployment package
    cd lambda/$FUNCTION_DIR
    
    # Skip pip install (boto3 is included in Lambda runtime)
    echo "Skipping pip install (boto3 is included in Lambda runtime)"
    
    # Create ZIP file
    zip -r function.zip . -x "*.pyc" -x "__pycache__/*" -x "*.zip"
    
    # Check if function exists
    FUNCTION_EXISTS=$(aws lambda get-function --function-name $FUNCTION_NAME --region $REGION 2>/dev/null || echo "")
    
    if [ -z "$FUNCTION_EXISTS" ]; then
        # Create new function
        echo "Creating new function: $FUNCTION_NAME"
        aws lambda create-function \
            --function-name $FUNCTION_NAME \
            --runtime python3.11 \
            --role $ROLE_ARN \
            --handler $HANDLER \
            --zip-file fileb://function.zip \
            --timeout $TIMEOUT \
            --memory-size $MEMORY \
            --region $REGION \
            --environment Variables="{
                BEDROCK_MODEL_ID=apac.anthropic.claude-3-5-sonnet-20240620-v1:0,
                HSN_TABLE_NAME=HSNCodeMaster,
                AUDIT_TABLE_NAME=AuditLog,
                HISTORY_TABLE_NAME=DocumentHistory,
                S3_BUCKET=niryatsaathi-documents-${ACCOUNT_ID}
            }"
    else
        # Update existing function
        echo "Updating existing function: $FUNCTION_NAME"
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --zip-file fileb://function.zip \
            --region $REGION
        
        echo "Waiting for function to be ready..."
        sleep 5
        
        # Update configuration
        aws lambda update-function-configuration \
            --function-name $FUNCTION_NAME \
            --timeout $TIMEOUT \
            --memory-size $MEMORY \
            --region $REGION
    fi
    
    # Clean up
    rm function.zip
    cd ../..
    
    echo "✓ $FUNCTION_NAME deployed successfully"
    echo ""
}

# Deploy DocumentProcessor
deploy_lambda \
    "DocumentProcessor" \
    "document-processor" \
    "NiryatSaathi-DocumentProcessor-Role" \
    "lambda_function.lambda_handler" \
    1024 \
    60

# Deploy DocumentValidator
deploy_lambda \
    "DocumentValidator" \
    "document-validator" \
    "NiryatSaathi-DocumentValidator-Role" \
    "lambda_function.lambda_handler" \
    512 \
    30

# Deploy HSNDataLoader
deploy_lambda \
    "HSNDataLoader" \
    "hsn-data-loader" \
    "NiryatSaathi-HSNClassifier-Role" \
    "lambda_function.lambda_handler" \
    512 \
    300

echo "========================================="
echo "All remaining Lambda functions deployed!"
echo "========================================="
echo ""
echo "Deployed functions:"
echo "- DocumentProcessor"
echo "- DocumentValidator"
echo "- HSNDataLoader"
echo ""
echo "Next step: Load HSN data"
echo "./scripts/load-hsn-data.sh"
