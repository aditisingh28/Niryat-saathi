#!/bin/bash

# Test HSN Classifier Lambda function
# Usage: ./scripts/test-hsn-classifier.sh

set -e

REGION="ap-south-1"

echo "========================================="
echo "Testing HSN Classifier"
echo "========================================="
echo ""

# Test 1: English product description
echo "Test 1: Handmade turmeric soap (English)"
echo "----------------------------------------"
cat > /tmp/test1-payload.json << 'EOF'
{"body":"{\"product_description\":\"handmade turmeric soap\",\"language\":\"en\",\"user_id\":\"test_user\"}"}
EOF
aws lambda invoke \
    --function-name HSNClassifier \
    --region $REGION \
    --cli-binary-format raw-in-base64-out \
    --payload file:///tmp/test1-payload.json \
    /tmp/test1-response.json

echo "Response:"
cat /tmp/test1-response.json | jq '.body | fromjson'
echo ""
echo ""

# Test 2: Hindi product description
echo "Test 2: हल्दी साबुन (Hindi)"
echo "----------------------------------------"
cat > /tmp/test2-payload.json << 'EOF'
{"body":"{\"product_description\":\"हाथ से बना हल्दी साबुन\",\"language\":\"hi\",\"user_id\":\"test_user\"}"}
EOF
aws lambda invoke \
    --function-name HSNClassifier \
    --region $REGION \
    --cli-binary-format raw-in-base64-out \
    --payload file:///tmp/test2-payload.json \
    /tmp/test2-response.json

echo "Response:"
cat /tmp/test2-response.json | jq '.body | fromjson'
echo ""
echo ""

# Test 3: Cotton bedsheets
echo "Test 3: Cotton bedsheets"
echo "----------------------------------------"
cat > /tmp/test3-payload.json << 'EOF'
{"body":"{\"product_description\":\"cotton bedsheets\",\"language\":\"en\",\"user_id\":\"test_user\"}"}
EOF
aws lambda invoke \
    --function-name HSNClassifier \
    --region $REGION \
    --cli-binary-format raw-in-base64-out \
    --payload file:///tmp/test3-payload.json \
    /tmp/test3-response.json

echo "Response:"
cat /tmp/test3-response.json | jq '.body | fromjson'
echo ""
echo ""

# Test 4: Basmati rice
echo "Test 4: Basmati rice"
echo "----------------------------------------"
cat > /tmp/test4-payload.json << 'EOF'
{"body":"{\"product_description\":\"basmati rice\",\"language\":\"en\",\"user_id\":\"test_user\"}"}
EOF
aws lambda invoke \
    --function-name HSNClassifier \
    --region $REGION \
    --cli-binary-format raw-in-base64-out \
    --payload file:///tmp/test4-payload.json \
    /tmp/test4-response.json

echo "Response:"
cat /tmp/test4-response.json | jq '.body | fromjson'
echo ""
echo ""

echo "========================================="
echo "HSN Classifier tests completed!"
echo "========================================="
echo ""
echo "Check /tmp/test*-response.json for detailed responses"
