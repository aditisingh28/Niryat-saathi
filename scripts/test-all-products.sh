#!/bin/bash

# Test HSN Classifier with 20 common export products
# Usage: ./scripts/test-all-products.sh

API_URL="https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod/api/v1/classify-product"

echo "========================================="
echo "Testing HSN Classifier with 20 Products"
echo "========================================="
echo ""

# Array of test products
products=(
    "handmade turmeric soap"
    "cotton bedsheets"
    "frozen mango pulp"
    "basmati rice"
    "wooden toys"
    "leather jackets"
    "brass handicrafts"
    "cashew nuts"
    "black pepper"
    "CTC tea"
    "handloom sarees"
    "jute bags"
    "ayurvedic medicines"
    "banana chips"
    "ceramic tiles"
    "steel utensils"
    "incense sticks"
    "honey"
    "coconut oil"
    "cotton yarn"
)

# Expected HSN codes (for validation)
expected_hsn=(
    "34011190"
    "63022100"
    "0811909090"
    "10063020"
    "95030070"
    "42033000"
    "83062900"
    "08013200"
    "09041110"
    "09023010"
    "52084200"
    "42022210"
    "30049011"
    "20081990"
    "69089010"
    "73239390"
    "33074100"
    "04090000"
    "15131100"
    "52051100"
)

success_count=0
total_count=${#products[@]}
total_time=0

for i in "${!products[@]}"; do
    product="${products[$i]}"
    expected="${expected_hsn[$i]}"
    
    echo "[$((i+1))/$total_count] Testing: $product"
    echo "Expected HSN: $expected"
    
    start_time=$(date +%s%3N)
    
    response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "{\"product_description\":\"$product\"}")
    
    end_time=$(date +%s%3N)
    response_time=$((end_time - start_time))
    total_time=$((total_time + response_time))
    
    # Extract top HSN code
    top_hsn=$(echo "$response" | jq -r '.classifications[0].hsn_code' 2>/dev/null)
    confidence=$(echo "$response" | jq -r '.classifications[0].confidence' 2>/dev/null)
    
    if [ -z "$top_hsn" ] || [ "$top_hsn" = "null" ]; then
        echo "❌ FAILED: No HSN code returned"
        echo "Response: $response"
    else
        confidence_pct=$(echo "$confidence * 100" | bc | cut -d. -f1)
        echo "✓ Got HSN: $top_hsn (${confidence_pct}% confidence)"
        
        # Check if expected HSN is in top 3
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
echo "Accuracy: $(echo "scale=1; $success_count * 100 / $total_count" | bc)%"
echo "Average response time: $(echo "scale=0; $total_time / $total_count" | bc)ms"
echo ""

if [ $success_count -ge 15 ]; then
    echo "✅ PASSED: Accuracy target met (>75%)"
    exit 0
else
    echo "❌ FAILED: Accuracy below target (<75%)"
    exit 1
fi
