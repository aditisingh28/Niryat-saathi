#!/bin/bash

# Setup API Gateway endpoints for Document Validator
# Usage: ./scripts/setup-document-api.sh

set -e

REGION="ap-south-1"
API_ID="33m1wci2fb"  # Your existing API Gateway ID

echo "========================================="
echo "Setting up Document Validator API"
echo "========================================="
echo "API ID: $API_ID"
echo "Region: $REGION"
echo ""

# Get the root resource ID
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query 'items[?path==`/`].id' --output text)

echo "Root resource ID: $ROOT_ID"

# Check if /api/v1 resource exists
API_V1_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query 'items[?path==`/api/v1`].id' --output text)

if [ -z "$API_V1_ID" ]; then
    echo "Creating /api/v1 resource..."
    # This should already exist from HSN classifier setup
    echo "Error: /api/v1 resource not found. Please create it first."
    exit 1
fi

echo "/api/v1 resource ID: $API_V1_ID"

# Create /api/v1/upload-document resource
echo "Creating /api/v1/upload-document endpoint..."

UPLOAD_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query 'items[?path==`/api/v1/upload-document`].id' --output text)

if [ -z "$UPLOAD_RESOURCE_ID" ]; then
    UPLOAD_RESOURCE_ID=$(aws apigateway create-resource \
        --rest-api-id $API_ID \
        --parent-id $API_V1_ID \
        --path-part upload-document \
        --region $REGION \
        --query 'id' \
        --output text)
    echo "Created upload-document resource: $UPLOAD_RESOURCE_ID"
else
    echo "upload-document resource already exists: $UPLOAD_RESOURCE_ID"
fi

# Create POST method for upload-document
echo "Setting up POST method for upload-document..."

aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $UPLOAD_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE \
    --region $REGION 2>/dev/null || echo "POST method already exists"

# Get DocumentUpload Lambda ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
UPLOAD_LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:DocumentUpload"

# Integrate with Lambda
echo "Integrating with DocumentUpload Lambda..."

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $UPLOAD_RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${UPLOAD_LAMBDA_ARN}/invocations" \
    --region $REGION 2>/dev/null || echo "Integration already exists"

# Add Lambda permission
echo "Adding Lambda invoke permission..."

aws lambda add-permission \
    --function-name DocumentUpload \
    --statement-id apigateway-upload-document \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
    --region $REGION 2>/dev/null || echo "Permission already exists"

# Create /api/v1/validate-document resource
echo "Creating /api/v1/validate-document endpoint..."

VALIDATE_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query 'items[?path==`/api/v1/validate-document`].id' --output text)

if [ -z "$VALIDATE_RESOURCE_ID" ]; then
    VALIDATE_RESOURCE_ID=$(aws apigateway create-resource \
        --rest-api-id $API_ID \
        --parent-id $API_V1_ID \
        --path-part validate-document \
        --region $REGION \
        --query 'id' \
        --output text)
    echo "Created validate-document resource: $VALIDATE_RESOURCE_ID"
else
    echo "validate-document resource already exists: $VALIDATE_RESOURCE_ID"
fi

# Create POST method for validate-document
echo "Setting up POST method for validate-document..."

aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $VALIDATE_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE \
    --region $REGION 2>/dev/null || echo "POST method already exists"

# Get DocumentValidator Lambda ARN
VALIDATOR_LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:DocumentValidator"

# Integrate with Lambda
echo "Integrating with DocumentValidator Lambda..."

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $VALIDATE_RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${VALIDATOR_LAMBDA_ARN}/invocations" \
    --region $REGION 2>/dev/null || echo "Integration already exists"

# Add Lambda permission
echo "Adding Lambda invoke permission..."

aws lambda add-permission \
    --function-name DocumentValidator \
    --statement-id apigateway-validate-document \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
    --region $REGION 2>/dev/null || echo "Permission already exists"

# Deploy API
echo "Deploying API to prod stage..."

aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $REGION

echo ""
echo "========================================="
echo "API Setup Complete!"
echo "========================================="
echo ""
echo "Endpoints:"
echo "POST https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/api/v1/upload-document"
echo "POST https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/api/v1/validate-document"
echo ""
