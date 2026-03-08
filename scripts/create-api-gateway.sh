#!/bin/bash

# Create API Gateway for NiryatSaathi
# Usage: ./scripts/create-api-gateway.sh

set -e

REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "========================================="
echo "Creating API Gateway"
echo "========================================="
echo ""

# Create API Gateway
echo "Creating REST API..."
API_ID=$(aws apigateway create-rest-api \
  --name "NiryatSaathi-API" \
  --region $REGION \
  --query 'id' \
  --output text)

echo "API ID: $API_ID"
echo ""

# Get root resource
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --region $REGION \
  --query 'items[0].id' \
  --output text)

# Create /api resource
echo "Creating /api resource..."
API_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part api \
  --region $REGION \
  --query 'id' \
  --output text)

# Create /api/v1 resource
echo "Creating /api/v1 resource..."
V1_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $API_RESOURCE \
  --path-part v1 \
  --region $REGION \
  --query 'id' \
  --output text)

# Create /api/v1/classify-product resource
echo "Creating /api/v1/classify-product resource..."
CLASSIFY_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $V1_RESOURCE \
  --path-part classify-product \
  --region $REGION \
  --query 'id' \
  --output text)

# Get Lambda ARN
LAMBDA_ARN=$(aws lambda get-function \
  --function-name HSNClassifier \
  --region $REGION \
  --query 'Configuration.FunctionArn' \
  --output text)

echo "Lambda ARN: $LAMBDA_ARN"
echo ""

# Create POST method
echo "Creating POST method..."
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $CLASSIFY_RESOURCE \
  --http-method POST \
  --authorization-type NONE \
  --region $REGION > /dev/null

# Set up Lambda integration
echo "Setting up Lambda integration..."
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $CLASSIFY_RESOURCE \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
  --region $REGION > /dev/null

# Give API Gateway permission to invoke Lambda
echo "Adding Lambda permissions..."
aws lambda add-permission \
  --function-name HSNClassifier \
  --statement-id apigateway-invoke-$(date +%s) \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
  --region $REGION > /dev/null 2>&1 || echo "Permission already exists"

# Enable CORS - OPTIONS method
echo "Enabling CORS..."
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $CLASSIFY_RESOURCE \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region $REGION > /dev/null

aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $CLASSIFY_RESOURCE \
  --http-method OPTIONS \
  --type MOCK \
  --region $REGION > /dev/null

aws apigateway put-method-response \
  --rest-api-id $API_ID \
  --resource-id $CLASSIFY_RESOURCE \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters method.response.header.Access-Control-Allow-Headers=false,method.response.header.Access-Control-Allow-Methods=false,method.response.header.Access-Control-Allow-Origin=false \
  --region $REGION > /dev/null

aws apigateway put-integration-response \
  --rest-api-id $API_ID \
  --resource-id $CLASSIFY_RESOURCE \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"'"'","method.response.header.Access-Control-Allow-Methods":"'"'"'POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin":"'"'"'*'"'"'"}' \
  --region $REGION > /dev/null

# Deploy API
echo "Deploying API to prod stage..."
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --region $REGION > /dev/null

echo ""
echo "========================================="
echo "API Gateway Created Successfully!"
echo "========================================="
echo ""
echo "API URL: https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod"
echo ""
echo "Test it with:"
echo "curl -X POST https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/api/v1/classify-product \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"product_description\":\"handmade soap\",\"language\":\"en\",\"user_id\":\"test\"}'"
echo ""
echo "Next step: Start frontend with this API URL"
echo "cd frontend"
echo "echo 'REACT_APP_API_URL=https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod' > .env"
echo "npm install"
echo "npm start"
