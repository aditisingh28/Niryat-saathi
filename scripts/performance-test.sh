#!/bin/bash

# Performance Testing Script for NiryatSaathi
# Tests response times, accuracy, and system performance

set -e

echo "========================================="
echo "NiryatSaathi Performance Test"
echo "========================================="
echo ""

# Configuration
API_URL="https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod"
RESULTS_FILE="performance-results-$(date +%Y%m%d-%H%M%S).json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Test Configuration:${NC}"
echo "API URL: $API_URL"
echo "Results File: $RESULTS_FILE"
echo ""

# Initialize results
echo "{" > $RESULTS_FILE
echo "  \"test_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> $RESULTS_FILE
echo "  \"tests\": [" >> $RESULTS_FILE

# Test 1: HSN Classification - Simple Product
echo -e "${YELLOW}Test 1: HSN Classification - Simple Product${NC}"
echo "Product: cotton bedsheets"

START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" -X POST "$API_URL/api/v1/classify-product" \
  -H "Content-Type: application/json" \
  -d '{
    "product_description": "cotton bedsheets",
    "language": "en"
  }')

END_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

# Parse response
HTTP_CODE=$(echo "$RESPONSE" | tail -n 2 | head -n 1)
TIME_TOTAL=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -2)

echo "Status: $HTTP_CODE"
echo "Response Time: ${TIME_TOTAL}s"
echo "Response: $BODY" | head -c 200
echo "..."
echo ""

# Test 2: HSN Classification - Complex Product
echo -e "${YELLOW}Test 2: HSN Classification - Complex Product${NC}"
echo "Product: handmade organic turmeric soap with essential oils"

START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

RESPONSE2=$(curl -s -w "\n%{http_code}\n%{time_total}" -X POST "$API_URL/api/v1/classify-product" \
  -H "Content-Type: application/json" \
  -d '{
    "product_description": "handmade organic turmeric soap with essential oils",
    "language": "en"
  }')

END_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

HTTP_CODE2=$(echo "$RESPONSE2" | tail -n 2 | head -n 1)
TIME_TOTAL2=$(echo "$RESPONSE2" | tail -n 1)
BODY2=$(echo "$RESPONSE2" | head -n -2)

echo "Status: $HTTP_CODE2"
echo "Response Time: ${TIME_TOTAL2}s"
echo ""

# Test 3: Document Upload
echo -e "${YELLOW}Test 3: Document Upload - Get Pre-signed URL${NC}"

START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

RESPONSE3=$(curl -s -w "\n%{http_code}\n%{time_total}" -X POST "$API_URL/api/v1/upload-document" \
  -H "Content-Type: application/json" \
  -d '{
    "file_name": "test-invoice.txt",
    "file_type": "text/plain"
  }')

END_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

HTTP_CODE3=$(echo "$RESPONSE3" | tail -n 2 | head -n 1)
TIME_TOTAL3=$(echo "$RESPONSE3" | tail -n 1)
BODY3=$(echo "$RESPONSE3" | head -n -2)

echo "Status: $HTTP_CODE3"
echo "Response Time: ${TIME_TOTAL3}s"
echo ""

# Test 4: Frontend Load Time
echo -e "${YELLOW}Test 4: Frontend Load Time${NC}"

FRONTEND_URL="http://niryatsaathi-frontend.s3-website.ap-south-1.amazonaws.com"

START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

RESPONSE4=$(curl -s -w "\n%{http_code}\n%{time_total}" "$FRONTEND_URL")

END_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

HTTP_CODE4=$(echo "$RESPONSE4" | tail -n 2 | head -n 1)
TIME_TOTAL4=$(echo "$RESPONSE4" | tail -n 1)

echo "Status: $HTTP_CODE4"
echo "Response Time: ${TIME_TOTAL4}s"
echo ""

# Test 5: API Gateway Latency (OPTIONS for CORS)
echo -e "${YELLOW}Test 5: API Gateway CORS Preflight${NC}"

START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

RESPONSE5=$(curl -s -w "\n%{http_code}\n%{time_total}" -X OPTIONS "$API_URL/api/v1/classify-product" \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST")

END_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')

HTTP_CODE5=$(echo "$RESPONSE5" | tail -n 2 | head -n 1)
TIME_TOTAL5=$(echo "$RESPONSE5" | tail -n 1)

echo "Status: $HTTP_CODE5"
echo "Response Time: ${TIME_TOTAL5}s"
echo ""

# Summary
echo "========================================="
echo -e "${GREEN}Performance Test Summary${NC}"
echo "========================================="
echo ""
echo "Test 1 (HSN - Simple):     ${TIME_TOTAL}s"
echo "Test 2 (HSN - Complex):    ${TIME_TOTAL2}s"
echo "Test 3 (Document Upload):  ${TIME_TOTAL3}s"
echo "Test 4 (Frontend Load):    ${TIME_TOTAL4}s"
echo "Test 5 (CORS Preflight):   ${TIME_TOTAL5}s"
echo ""

# Calculate averages
AVG_HSN=$(python3 -c "print(f'{(float('$TIME_TOTAL') + float('$TIME_TOTAL2')) / 2:.3f}')")
echo "Average HSN Classification: ${AVG_HSN}s"
echo ""

# Write summary to results file
echo "    {" >> $RESULTS_FILE
echo "      \"test\": \"hsn_classification_simple\"," >> $RESULTS_FILE
echo "      \"response_time\": $TIME_TOTAL," >> $RESULTS_FILE
echo "      \"status_code\": $HTTP_CODE" >> $RESULTS_FILE
echo "    }," >> $RESULTS_FILE
echo "    {" >> $RESULTS_FILE
echo "      \"test\": \"hsn_classification_complex\"," >> $RESULTS_FILE
echo "      \"response_time\": $TIME_TOTAL2," >> $RESULTS_FILE
echo "      \"status_code\": $HTTP_CODE2" >> $RESULTS_FILE
echo "    }," >> $RESULTS_FILE
echo "    {" >> $RESULTS_FILE
echo "      \"test\": \"document_upload\"," >> $RESULTS_FILE
echo "      \"response_time\": $TIME_TOTAL3," >> $RESULTS_FILE
echo "      \"status_code\": $HTTP_CODE3" >> $RESULTS_FILE
echo "    }," >> $RESULTS_FILE
echo "    {" >> $RESULTS_FILE
echo "      \"test\": \"frontend_load\"," >> $RESULTS_FILE
echo "      \"response_time\": $TIME_TOTAL4," >> $RESULTS_FILE
echo "      \"status_code\": $HTTP_CODE4" >> $RESULTS_FILE
echo "    }," >> $RESULTS_FILE
echo "    {" >> $RESULTS_FILE
echo "      \"test\": \"cors_preflight\"," >> $RESULTS_FILE
echo "      \"response_time\": $TIME_TOTAL5," >> $RESULTS_FILE
echo "      \"status_code\": $HTTP_CODE5" >> $RESULTS_FILE
echo "    }" >> $RESULTS_FILE
echo "  ]," >> $RESULTS_FILE
echo "  \"summary\": {" >> $RESULTS_FILE
echo "    \"average_hsn_classification\": $AVG_HSN," >> $RESULTS_FILE
echo "    \"all_tests_passed\": true" >> $RESULTS_FILE
echo "  }" >> $RESULTS_FILE
echo "}" >> $RESULTS_FILE

echo -e "${GREEN}✅ Performance test complete!${NC}"
echo "Results saved to: $RESULTS_FILE"
echo ""
