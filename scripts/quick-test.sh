#!/bin/bash

# Quick test of HSN Classifier with 5 products
# Usage: ./scripts/quick-test.sh

API_URL="https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod/api/v1/classify-product"

echo "========================================="
echo "Quick HSN Classifier Test (5 Products)"
echo "========================================="
echo ""

test_product() {
    local product="$1"
    local expected="$2"
    
    echo "Testing: $product"
    echo "Expected HSN: $expected"
    
    start=$(python3 -c 'import time; print(int(time.time() * 1000))')
    response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{\"product_description\":\"$product\"}")
    end=$(python3 -c 'import time; print(int(time.time() * 1000))')
    
    time=$((end - start))
    
    top_hsn=$(echo "$response" | jq -r '.classifications[0].hsn_code' 2>/dev/null)
    confidence=$(echo "$response" | jq -r '.classifications[0].confidence' 2>/dev/null)
    
    if [ -z "$top_hsn" ] || [ "$top_hsn" = "null" ]; then
        echo "❌ FAILED: No response"
        return 1
    fi
    
    confidence_pct=$(printf "%.0f" $(echo "$confidence * 100" | bc))
    echo "✓ Result: $top_hsn (${confidence_pct}% confidence, ${time}ms)"
    
    all_hsn=$(echo "$response" | jq -r '.classifications[].hsn_code' 2>/dev/null | tr '\n' ' ')
    
    if echo "$all_hsn" | grep -q "$expected"; then
        echo "✅ PASS: Expected HSN in top 3"
        echo ""
        return 0
    else
        echo "⚠️  WARN: Expected not found. Got: $all_hsn"
        echo ""
        return 1
    fi
}

success=0
total=5

test_product "handmade turmeric soap" "34011" && ((success++))
test_product "cotton bedsheets" "6302" && ((success++))
test_product "basmati rice" "1006" && ((success++))
test_product "wooden toys" "9503" && ((success++))
test_product "black pepper" "0904" && ((success++))

echo "========================================="
echo "Results: $success/$total passed ($(echo "scale=0; $success * 100 / $total" | bc)%)"
echo "========================================="

[ $success -ge 4 ] && echo "✅ Test PASSED" || echo "❌ Test FAILED"
