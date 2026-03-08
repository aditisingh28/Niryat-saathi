#!/bin/bash

# Simple Performance Testing Script for NiryatSaathi
# Tests response times and system performance

echo "========================================="
echo "NiryatSaathi Performance Test"
echo "========================================="
echo ""

API_URL="https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod"

echo "Test 1: HSN Classification - Cotton Bedsheets"
echo "----------------------------------------------"
time curl -s -X POST "$API_URL/api/v1/classify-product" \
  -H "Content-Type: application/json" \
  -d '{"product_description": "cotton bedsheets", "language": "en"}' \
  -o /tmp/test1.json
echo ""
echo "Response saved to /tmp/test1.json"
cat /tmp/test1.json | python3 -m json.tool 2>/dev/null | head -20
echo ""
echo ""

echo "Test 2: HSN Classification - Turmeric Soap"
echo "----------------------------------------------"
time curl -s -X POST "$API_URL/api/v1/classify-product" \
  -H "Content-Type: application/json" \
  -d '{"product_description": "handmade turmeric soap", "language": "en"}' \
  -o /tmp/test2.json
echo ""
echo "Response saved to /tmp/test2.json"
cat /tmp/test2.json | python3 -m json.tool 2>/dev/null | head -20
echo ""
echo ""

echo "Test 3: Document Upload - Get Pre-signed URL"
echo "----------------------------------------------"
time curl -s -X POST "$API_URL/api/v1/upload-document" \
  -H "Content-Type: application/json" \
  -d '{"file_name": "test.txt", "file_type": "text/plain"}' \
  -o /tmp/test3.json
echo ""
echo "Response saved to /tmp/test3.json"
cat /tmp/test3.json | python3 -m json.tool 2>/dev/null
echo ""
echo ""

echo "Test 4: Frontend Load Time"
echo "----------------------------------------------"
time curl -s "http://niryatsaathi-frontend.s3-website.ap-south-1.amazonaws.com" \
  -o /tmp/test4.html
echo ""
SIZE=$(wc -c < /tmp/test4.html)
echo "Frontend HTML size: $SIZE bytes"
echo ""
echo ""

echo "Test 5: API Gateway CORS Preflight"
echo "----------------------------------------------"
time curl -s -X OPTIONS "$API_URL/api/v1/classify-product" \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -o /tmp/test5.txt
echo ""
echo ""

echo "========================================="
echo "Performance Test Complete!"
echo "========================================="
echo ""
echo "All response files saved to /tmp/test*.json"
echo ""
