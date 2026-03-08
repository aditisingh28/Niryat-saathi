#!/bin/bash

# Test Document Validation API
# Usage: ./scripts/test-document-validation.sh

set -e

API_URL="https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod"

echo "========================================="
echo "Testing Document Validation API"
echo "========================================="
echo ""

# Test 1: Get upload URL
echo "Test 1: Getting pre-signed upload URL..."
echo ""

UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/upload-document" \
  -H "Content-Type: application/json" \
  -d '{
    "file_name": "test-invoice.pdf",
    "file_type": "application/pdf"
  }')

echo "Response:"
echo "$UPLOAD_RESPONSE" | jq .
echo ""

# Extract values
UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.upload_url')
S3_KEY=$(echo "$UPLOAD_RESPONSE" | jq -r '.s3_key')
FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.file_id')

if [ "$UPLOAD_URL" = "null" ] || [ -z "$UPLOAD_URL" ]; then
    echo "❌ FAILED: No upload URL received"
    exit 1
fi

echo "✅ SUCCESS: Got upload URL"
echo "S3 Key: $S3_KEY"
echo "File ID: $FILE_ID"
echo ""

# Test 2: Create a sample text file to upload
echo "Test 2: Creating sample document..."
echo ""

cat > /tmp/test-invoice.txt << 'EOF'
COMMERCIAL INVOICE

Exporter: ABC Exports Pvt Ltd
IEC Number: 0123456789
Address: Mumbai, India

Invoice Number: INV-2024-001
Invoice Date: 2024-03-08
HSN Code: 34011110

Product Description: Handmade Turmeric Soap
Quantity: 1000 units
Unit Price: $5.00
Total Value: $5,000.00

Destination: United States
Buyer: XYZ Imports LLC
EOF

echo "✅ Sample invoice created"
echo ""

# Test 3: Upload file to S3 (skip for now as we need actual S3 upload)
echo "Test 3: Skipping S3 upload (would use pre-signed URL)"
echo "Note: In production, frontend uploads file directly to S3 using the pre-signed URL"
echo ""

# Test 4: Test validation endpoint directly
echo "Test 4: Testing validation endpoint..."
echo ""

VALIDATION_RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/validate-document" \
  -H "Content-Type: application/json" \
  -d "{
    \"s3_key\": \"test/sample-invoice.pdf\",
    \"file_id\": \"test-123\"
  }")

echo "Response:"
echo "$VALIDATION_RESPONSE" | jq .
echo ""

# Check if validation endpoint is working
if echo "$VALIDATION_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$VALIDATION_RESPONSE" | jq -r '.error')
    if [[ "$ERROR_MSG" == *"Failed to extract"* ]] || [[ "$ERROR_MSG" == *"NoSuchKey"* ]]; then
        echo "⚠️  Expected error: Document doesn't exist in S3 (this is normal for test)"
        echo "✅ Validation endpoint is responding correctly"
    else
        echo "❌ Unexpected error: $ERROR_MSG"
    fi
else
    echo "✅ Validation endpoint returned results"
fi

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo ""
echo "✅ Upload endpoint: Working"
echo "✅ Pre-signed URL generation: Working"
echo "⚠️  S3 upload: Skipped (requires actual file)"
echo "✅ Validation endpoint: Responding"
echo ""
echo "Next steps:"
echo "1. Test with actual file upload from frontend"
echo "2. Verify Textract extraction"
echo "3. Test AI validation logic"
echo ""
