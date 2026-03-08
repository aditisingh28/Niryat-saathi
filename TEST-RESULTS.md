# NiryatSaathi - Test Results

## HSN Classifier Test Results

### Test Date: March 8, 2026

### Test Configuration
- **API Endpoint**: https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod/api/v1/classify-product
- **AI Model**: Qwen 3 (235B) - qwen.qwen3-235b-a22b-2507-v1:0
- **Test Products**: 10 common export items
- **Success Criteria**: >75% accuracy

### Results Summary
- **Total Products Tested**: 10
- **Successful Matches**: 7
- **Accuracy**: 70.0%
- **Average Response Time**: 5.2 seconds
- **Status**: ⚠️ Below target (need 75%)

### Detailed Results

| # | Product | Expected HSN | Got HSN | Confidence | Status |
|---|---------|--------------|---------|------------|--------|
| 1 | Handmade turmeric soap | 3401* | 34011110 | 94% | ✅ PASS |
| 2 | Cotton bedsheets | 6302* | null | 50% | ❌ FAIL |
| 3 | Basmati rice | 1006* | 10064010 | 98% | ✅ PASS |
| 4 | Wooden toys | 9503* | 95030010 | 98% | ✅ PASS |
| 5 | Black pepper | 0904* | 09040000 | 98% | ✅ PASS |
| 6 | Handloom sarees | 5208* | 54079200 | 95% | ⚠️ WRONG |
| 7 | Jute bags | 4202* | 42022210 | 95% | ✅ PASS |
| 8 | Banana chips | 2008* | 20089910 | 95% | ✅ PASS |
| 9 | Honey | 0409* | null | 50% | ❌ FAIL |
| 10 | Coconut oil | 1513* | 15131100 | 98% | ✅ PASS |

### Issues Identified

1. **Null HSN Codes** (2 cases)
   - Cotton bedsheets
   - Honey
   - Issue: AI model returning null instead of HSN code
   - Fix needed: Improve prompt or add fallback logic

2. **Wrong Classification** (1 case)
   - Handloom sarees: Got 54079200 (synthetic fabrics) instead of 5208* (cotton fabrics)
   - Issue: Model confused material type
   - Fix needed: Add material context to prompt

### Performance Metrics

- **Response Time Range**: 3.5s - 9.4s
- **Average Response Time**: 5.2s
- **Target**: <5 seconds
- **Status**: ⚠️ Slightly above target

### Recommendations

1. **Improve Prompt Engineering**
   - Add more context about product materials
   - Request explicit HSN code format validation
   - Add fallback instructions for ambiguous products

2. **Add Validation Layer**
   - Check for null HSN codes before returning
   - Retry with simplified prompt if null
   - Add default HSN code suggestions

3. **Optimize Performance**
   - Consider caching common products
   - Reduce max_tokens if possible
   - Use faster model for simple products

### Quick Test Results (5 Products)

Previous quick test showed **100% accuracy** on:
- Handmade turmeric soap ✅
- Cotton bedsheets ✅
- Basmati rice ✅
- Wooden toys ✅
- Black pepper ✅

Note: Cotton bedsheets passed in quick test but failed in comprehensive test, suggesting intermittent AI response issues.

### Conclusion

The HSN Classifier achieves **70% accuracy**, which is close to the 75% target. The main issues are:
1. Occasional null responses from AI (20% failure rate)
2. One misclassification due to material confusion

With prompt improvements and validation logic, the system can easily exceed 75% accuracy.

### Next Steps

1. ✅ Add null check and retry logic
2. ✅ Improve prompt with material context
3. ✅ Test again with fixes
4. ⏳ Document final results
