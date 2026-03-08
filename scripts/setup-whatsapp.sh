#!/bin/bash

# Setup WhatsApp Integration for NiryatSaathi
# This script creates all necessary AWS resources

set -e

echo "========================================="
echo "WhatsApp Integration Setup"
echo "========================================="
echo ""

# Configuration
REGION="ap-south-1"
FUNCTION_NAME="WhatsAppHandler"
TABLE_NAME="WhatsAppConversations"
API_ID="33m1wci2fb"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Creating DynamoDB Table${NC}"
echo ""

aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions AttributeName=phone_number,AttributeType=S \
  --key-schema AttributeName=phone_number,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION 2>/dev/null || echo "Table already exists"

echo -e "${GREEN}✅ DynamoDB table ready${NC}"
echo ""

echo -e "${YELLOW}Step 2: Installing Lambda dependencies${NC}"
echo ""

cd lambda/whatsapp-handler
pip3 install -r requirements.txt -t . --upgrade
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

echo -e "${YELLOW}Step 3: Creating Lambda deployment package${NC}"
echo ""

zip -r function.zip . -x "*.pyc" -x "__pycache__/*"
echo -e "${GREEN}✅ Deployment package created${NC}"
echo ""

echo -e "${YELLOW}Step 4: Deploying Lambda function${NC}"
echo ""

# Check if function exists
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION 2>/dev/null; then
    echo "Updating existing function..."
    aws lambda update-function-code \
      --function-name $FUNCTION_NAME \
      --zip-file fileb://function.zip \
      --region $REGION
else
    echo "Creating new function..."
    aws lambda create-function \
      --function-name $FUNCTION_NAME \
      --runtime python3.11 \
      --role arn:aws:iam::262343431547:role/NiryatSaathi-DocumentValidator-Role \
      --handler lambda_function.lambda_handler \
      --zip-file fileb://function.zip \
      --timeout 30 \
      --memory-size 256 \
      --environment Variables="{
        VERIFY_TOKEN=niryatsaathi_verify_token,
        CONVERSATION_TABLE=$TABLE_NAME
      }" \
      --region $REGION
fi

rm function.zip
cd ../..

echo -e "${GREEN}✅ Lambda function deployed${NC}"
echo ""

echo -e "${YELLOW}Step 5: Setting up API Gateway${NC}"
echo ""

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION | jq -r '.items[] | select(.path == "/api/v1") | .id')

# Create /whatsapp resource
WHATSAPP_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part whatsapp \
  --region $REGION 2>/dev/null | jq -r '.id' || \
  aws apigateway get-resources --rest-api-id $API_ID --region $REGION | jq -r '.items[] | select(.path == "/api/v1/whatsapp") | .id')

# Create /webhook resource
WEBHOOK_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $WHATSAPP_ID \
  --path-part webhook \
  --region $REGION 2>/dev/null | jq -r '.id' || \
  aws apigateway get-resources --rest-api-id $API_ID --region $REGION | jq -r '.items[] | select(.path == "/api/v1/whatsapp/webhook") | .id')

echo "Webhook resource ID: $WEBHOOK_ID"

# Add GET method (for webhook verification)
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $WEBHOOK_ID \
  --http-method GET \
  --authorization-type NONE \
  --region $REGION 2>/dev/null || echo "GET method exists"

# Add POST method (for messages)
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $WEBHOOK_ID \
  --http-method POST \
  --authorization-type NONE \
  --region $REGION 2>/dev/null || echo "POST method exists"

# Get Lambda ARN
LAMBDA_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --region $REGION | jq -r '.Configuration.FunctionArn')

# Add Lambda integration for GET
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $WEBHOOK_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
  --region $REGION 2>/dev/null || echo "GET integration exists"

# Add Lambda integration for POST
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $WEBHOOK_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
  --region $REGION 2>/dev/null || echo "POST integration exists"

# Add Lambda permissions
aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id apigateway-get \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:262343431547:$API_ID/*/GET/api/v1/whatsapp/webhook" \
  --region $REGION 2>/dev/null || echo "GET permission exists"

aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id apigateway-post \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:262343431547:$API_ID/*/POST/api/v1/whatsapp/webhook" \
  --region $REGION 2>/dev/null || echo "POST permission exists"

echo -e "${GREEN}✅ API Gateway configured${NC}"
echo ""

echo -e "${YELLOW}Step 6: Deploying API${NC}"
echo ""

aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --region $REGION

echo -e "${GREEN}✅ API deployed${NC}"
echo ""

echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Webhook URL:"
echo "https://$API_ID.execute-api.$REGION.amazonaws.com/prod/api/v1/whatsapp/webhook"
echo ""
echo "Verify Token:"
echo "niryatsaathi_verify_token"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Go to Meta Business Manager"
echo "2. Configure WhatsApp Business API"
echo "3. Set webhook URL (above)"
echo "4. Set verify token (above)"
echo "5. Update Lambda environment variables:"
echo "   - WHATSAPP_TOKEN=<your_token>"
echo "   - WHATSAPP_PHONE_ID=<your_phone_id>"
echo ""
echo "To update environment variables:"
echo "aws lambda update-function-configuration \\"
echo "  --function-name $FUNCTION_NAME \\"
echo "  --environment Variables=\"{WHATSAPP_TOKEN=YOUR_TOKEN,WHATSAPP_PHONE_ID=YOUR_PHONE_ID,VERIFY_TOKEN=niryatsaathi_verify_token,CONVERSATION_TABLE=$TABLE_NAME}\" \\"
echo "  --region $REGION"
echo ""
