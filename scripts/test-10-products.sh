#!/bin/bash

# Test HSN Classifier with 10 products
# Usage: ./scripts/test-10-products.sh

API_URL="https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod/api/v1/classify-product"

echo "========================================="
echo "Testing HSN Classifier (10 Products)"
echo "========================================="
echo ""

# Array of test products
products=(
    "handmade turmeric soap"
    "cotton bedsheets"
    "basmati rice"
    "wooden toys"
    "black pepper"
    "handloom sarees"
    "jute bags"
    "banana chips"
    "honey"
    "coconut oil"
)

# Expected HSN codes (first 4 digits for matching)
expected_hsn=(
    "3401"
    "6302"
    "1006"
    "9503"
    "0904"
    "5208"
    "4202"
    "2008"
    "0409"
    "1513"
)

success_count=0
total_count=${#products[@]}
total_time=0

for i in "${!products[@]}"; do
    product="${products[$i]}"
    expected="${expected_hsn[$i]}"
    
    echo "[$((i+1))/$total_count] Testing: $product"
    echo "Expected HSN: $expected*"
    
    start_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
    
    response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{\"product_description\":\"$product\"}")
    
    end_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
    response_time=$((end_time - start_time))
    total_time=$((total_time + response_time))
    
    # Extract top HSN code
    top_hsn=$(echo "$response" | jq -r '.classifications[0].hsn_code' 2>/dev/null)
    confidence=$(echo "$response" | jq -r '.classifications[0].confidence' 2>/dev/null)
    
    if [ -z "$top_hsn" ] || [ "$top_hsn" = "null" ]; then
        echo "❌ FAILED: No HSN code returned"
        echo "Response: $response"
    else
        confidence_pct=$(printf "%.0f" $(echo "$confidence * 100" | bc))
        echo "✓ Got HSN: $top_hsn (${confidence_pct}% confidence)"
        
        # Check if expected HSN prefix is in top 3
        all_hsn=$(echo "$response" | jq -r '.classifications[].hsn_code' 2>/dev/null | tr '\n' ' ')
        
        if echo "$all_hsn" | grep -q "$expected"; then
            echo "✅ SUCCESS: Expected HSN found in top 3"
            success_count=$((success_count + 1))
        else
            echo "⚠️  WARNING: Expected HSN not in top 3"
            echo "   Top 3: $all_hsn"
        fi
    fi
    
    echo "Response time: ${response_time}ms"
    echo ""
    
    # Rate limiting - wait 1 second between requests
    sleep 1
done

echo "========================================="
echo "Test Results Summary"
echo "========================================="
echo "Total products tested: $total_count"
echo "Successful matches: $success_count"
accuracy=$(echo "scale=1; $success_count * 100 / $total_count" | bc)
echo "Accuracy: ${accuracy}%"
avg_time=$(echo "scale=0; $total_time / $total_count" | bc)
echo "Average response time: ${avg_time}ms"
echo ""

if [ $success_count -ge 8 ]; then
    echo "✅ PASSED: Accuracy target met (>75%)"
    exit 0
else
    echo "❌ FAILED: Accuracy below target (<75%)"
    exit 1
fi
