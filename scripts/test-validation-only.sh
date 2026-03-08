#!/bin/bash

# Test Document Validation (bypassing upload)
# This uploads directly to S3 and then tests validation

set -e

API_URL="https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod"
S3_BUCKET="niryatsaathi-documents-262343431547"

echo "========================================="
echo "Document Validation Test (Direct Upload)"
echo "========================================="
echo ""

# Step 1: Create sample invoice
echo "Step 1: Creating sample invoice..."
cat > /tmp/test-invoice.txt << 'EOF'
COMMERCIAL INVOICE

Exporter: ABC Exports Pvt Ltd
IEC Number: 0123456789
Address: 123 Export Street, Mumbai, Maharashtra 400001, India

Invoice Number: INV-2024-001
Invoice Date: 2024-03-08
HSN Code: 34011110

Product Description: Handmade Turmeric Soap
Quantity: 1000 units
Unit Price: USD 5.00
Total Value: USD 5,000.00

Destination Country: United States
Buyer: XYZ Imports LLC
EOF

echo "✅ Sample invoice created"
echo ""

# Step 2: Upload directly to S3
FILE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
S3_KEY="documents/test/${FILE_ID}.txt"

echo "Step 2: Uploading to S3..."
echo "S3 Key: $S3_KEY"

aws s3 cp /tmp/test-invoice.txt "s3://${S3_BUCKET}/${S3_KEY}" --content-type "text/plain"

if [ $? -eq 0 ]; then
    echo "✅ File uploaded to S3"
else
    echo "❌ Upload failed"
    exit 1
fi
echo ""

# Step 3: Wait for S3
echo "Step 3: Waiting 2 seconds..."
sleep 2
echo ""

# Step 4: Call validation endpoint
echo "Step 4: Validating document..."
VALIDATION_RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/validate-document" \
  -H "Content-Type: application/json" \
  -d "{
    \"s3_key\": \"$S3_KEY\",
    \"file_id\": \"$FILE_ID\"
  }")

echo "$VALIDATION_RESPONSE" | jq .
echo ""

# Step 5: Check results
echo "========================================="
echo "Results"
echo "========================================="
echo ""

if echo "$VALIDATION_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$VALIDATION_RESPONSE" | jq -r '.error')
    echo "❌ Validation failed: $ERROR_MSG"
    echo ""
    echo "Checking Lambda logs for details..."
    aws logs tail /aws/lambda/DocumentValidator --since 5m --format short --region ap-south-1 | tail -20
else
    echo "✅ Document validation completed!"
    echo ""
    echo "Status: $(echo "$VALIDATION_RESPONSE" | jq -r '.status')"
    echo ""
    echo "Extracted Fields:"
    echo "$VALIDATION_RESPONSE" | jq '.extracted_fields'
    echo ""
    if echo "$VALIDATION_RESPONSE" | jq -e '.errors | length > 0' > /dev/null 2>&1; then
        echo "Validation Errors:"
        echo "$VALIDATION_RESPONSE" | jq '.errors'
    else
        echo "✅ No validation errors!"
    fi
fi

echo ""
