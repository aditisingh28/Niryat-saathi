#!/bin/bash

# Update HSNClassifier with correct Bedrock model ID
# Usage: ./scripts/update-hsn-classifier.sh

set -e

REGION="ap-south-1"

echo "========================================="
echo "Updating HSNClassifier Lambda"
echo "========================================="
echo ""

cd lambda/hsn-classifier

# Remove any old zip files
rm -f function.zip

# Create clean zip with only Python file
echo "Creating deployment package..."
zip function.zip lambda_function.py

# Update Lambda function
echo "Updating Lambda function..."
aws lambda update-function-code \
  --function-name HSNClassifier \
  --zip-file fileb://function.zip \
  --region $REGION

# Clean up
rm function.zip

cd ../..

echo ""
echo "========================================="
echo "HSNClassifier updated successfully!"
echo "========================================="
echo ""
echo "Waiting 10 seconds for Lambda to be ready..."
sleep 10

echo ""
echo "Test with:"
echo "curl -X POST https://YOUR-API-ID.execute-api.ap-south-1.amazonaws.com/prod/api/v1/classify-product \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"product_description\":\"handmade soap\",\"language\":\"en\",\"user_id\":\"test\"}'"
