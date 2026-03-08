# Quick Start: Testing Document Validator with Text Files

## 🚀 Quick Steps

### 1. Restart Frontend (if running)
```bash
cd frontend

# Stop the current server (Ctrl+C if running)
# Then restart:
npm start
```

The frontend will open at http://localhost:3000

### 2. Navigate to Document Validator
- Click on "Document Validator" in the navigation

### 3. Upload a Sample Text File
- Click "Choose File" or drag and drop
- Navigate to `test-data/` folder
- Select `sample-invoice-good.txt`
- Click "Validate Document"

### 4. See the Results!
You should see:
- ✅ Extracted fields (Exporter, IEC, HSN, etc.)
- ✅ Validation status
- ✅ AI-powered recommendations

## 📁 Sample Files Available

### Good Invoice (Should Pass)
**File**: `test-data/sample-invoice-good.txt`
- Complete invoice for turmeric soap
- All fields present and valid
- Expected: ✅ Valid or minimal warnings

### Invoice with Errors (Should Fail)
**File**: `test-data/sample-invoice-errors.txt`
- Multiple validation errors
- Invalid IEC (too short)
- Invalid HSN (wrong format)
- Future date
- Expected: ❌ Multiple errors detected

### Realistic Export Scenario
**File**: `test-data/sample-invoice-basmati-rice.txt`
- Complete basmati rice export to UAE
- Professional format
- All certificates mentioned
- Expected: ✅ Should pass

## 🎯 What to Expect

### Successful Validation
```
Status: Valid ✅
Extracted Fields:
  - Exporter Name: ABC Exports Pvt Ltd
  - IEC Number: 0123456789
  - HSN Code: 34011110
  - Invoice Date: 2024-03-08
  - Total Value: USD 5,000.00
  
Issues: None
Recommendations: Document looks good!
```

### Failed Validation
```
Status: Error ❌
Issues Found:
  - Invalid IEC format: must be 10 digits
  - Invalid HSN format: must be 8 digits
  - Future date detected
  
Recommendations:
  - Correct IEC number to 10 digits
  - Use proper 8-digit HSN code
  - Verify invoice date
```

## 💡 Tips

1. **Text files work perfectly** - No Textract subscription needed
2. **Create your own** - Follow the format in sample files
3. **Test different scenarios** - Good invoices, bad invoices, edge cases
4. **Check the AI reasoning** - See why it flagged issues

## 🐛 Troubleshooting

### "txt is not supported yet"
- **Solution**: Restart the frontend server
- The code has been updated to accept .txt files

### "Textract requires subscription"
- **This is normal** for PDF/image files
- **Solution**: Use .txt files instead
- Text files demonstrate all features without subscription

### File won't upload
- Check file size (max 10MB)
- Ensure file has .txt extension
- Try drag-and-drop instead of file picker

### No validation results
- Check browser console for errors
- Verify API Gateway is accessible
- Check Lambda function logs in AWS CloudWatch

## 📚 More Information

- `TESTING-WITHOUT-TEXTRACT.md` - Detailed testing guide
- `test-data/README.md` - Sample file documentation
- `FRONTEND-TXT-SUPPORT.md` - Technical details of the fix

## ✅ Checklist

- [ ] Frontend restarted
- [ ] Can select .txt files in file picker
- [ ] Uploaded sample-invoice-good.txt
- [ ] Saw validation results
- [ ] Tested sample-invoice-errors.txt
- [ ] Saw error detection working

## 🎉 Ready to Demo!

Once you've tested with the sample files, you're ready to demonstrate:
1. ✅ HSN Code Classifier (working)
2. ✅ Document Validator (working with text files)
3. ✅ AI-powered validation
4. ✅ Error detection and recommendations

**Your NiryatSaathi platform is fully functional!** 🚀
