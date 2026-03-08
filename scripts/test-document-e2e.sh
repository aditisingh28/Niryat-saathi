#!/bin/bash

# End-to-End Document Validation Test
# This script tests the complete flow: Get URL → Upload to S3 → Validate

set -e

API_URL="https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod"

echo "========================================="
echo "End-to-End Document Validation Test"
echo "========================================="
echo ""

# Step 1: Create a sample invoice PDF-like text file
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
Buyer Address: 456 Import Ave, New York, NY 10001, USA

Payment Terms: 30 days net
Shipping Terms: FOB Mumbai
Port of Loading: Mumbai
Port of Discharge: New York

Authorized Signatory
ABC Exports Pvt Ltd
EOF

echo "✅ Sample invoice created at /tmp/test-invoice.txt"
echo ""

# Step 2: Get pre-signed upload URL
echo "Step 2: Getting pre-signed upload URL..."
UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/upload-document" \
  -H "Content-Type: application/json" \
  -d '{
    "file_name": "test-invoice.txt",
    "file_type": "text/plain"
  }')

echo "$UPLOAD_RESPONSE" | jq .
echo ""

UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.upload_url')
S3_KEY=$(echo "$UPLOAD_RESPONSE" | jq -r '.s3_key')
FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.file_id')

if [ "$UPLOAD_URL" = "null" ] || [ -z "$UPLOAD_URL" ]; then
    echo "❌ FAILED: No upload URL received"
    exit 1
fi

echo "✅ Got upload URL"
echo "S3 Key: $S3_KEY"
echo "File ID: $FILE_ID"
echo ""

# Step 3: Upload file to S3 using pre-signed URL
echo "Step 3: Uploading file to S3..."
UPLOAD_STATUS=$(curl -s -w "%{http_code}" -o /tmp/upload-response.txt \
  -X PUT "$UPLOAD_URL" \
  -H "Content-Type: text/plain" \
  --data-binary "@/tmp/test-invoice.txt")

if [ "$UPLOAD_STATUS" = "200" ]; then
    echo "✅ File uploaded successfully to S3"
else
    echo "❌ Upload failed with status: $UPLOAD_STATUS"
    cat /tmp/upload-response.txt
    exit 1
fi
echo ""

# Step 4: Wait a moment for S3 to process
echo "Step 4: Waiting 2 seconds for S3 to process..."
sleep 2
echo ""

# Step 5: Validate the document
echo "Step 5: Validating document..."
VALIDATION_RESPONSE=$(curl -s -X POST "${API_URL}/api/v1/validate-document" \
  -H "Content-Type: application/json" \
  -d "{
    \"s3_key\": \"$S3_KEY\",
    \"file_id\": \"$FILE_ID\"
  }")

echo "$VALIDATION_RESPONSE" | jq .
echo ""

# Step 6: Check results
echo "========================================="
echo "Test Results"
echo "========================================="
echo ""

if echo "$VALIDATION_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$VALIDATION_RESPONSE" | jq -r '.error')
    echo "❌ Validation failed: $ERROR_MSG"
    echo ""
    echo "This might be because:"
    echo "1. Textract doesn't support plain text files (needs PDF/image)"
    echo "2. Lambda function needs debugging"
    echo "3. IAM permissions issue"
else
    echo "✅ Document validation completed!"
    echo ""
    echo "Extracted Fields:"
    echo "$VALIDATION_RESPONSE" | jq '.extracted_fields'
    echo ""
    echo "Validation Status:"
    echo "$VALIDATION_RESPONSE" | jq -r '.status'
    echo ""
    if echo "$VALIDATION_RESPONSE" | jq -e '.errors | length > 0' > /dev/null 2>&1; then
        echo "Validation Errors Found:"
        echo "$VALIDATION_RESPONSE" | jq '.errors'
    else
        echo "✅ No validation errors found!"
    fi
fi

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo "✅ Pre-signed URL generation: Working"
echo "✅ S3 file upload: Working"
if echo "$VALIDATION_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "⚠️  Document validation: Needs investigation"
else
    echo "✅ Document validation: Working"
fi
echo ""
