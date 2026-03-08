# Testing Document Validator Without Textract

## Why This Message?

Amazon Textract is a paid AWS service that requires a subscription to extract text from images and PDFs. Since your AWS account doesn't have Textract enabled, the document validator can only process plain text files.

## Workaround for Testing

### Option 1: Use Text Files (Recommended for Demo)

Create a text file with invoice content and upload it. The validator will work perfectly!

#### Sample Invoice Text File

Create a file named `sample-invoice.txt` with this content:

```
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
```

#### How to Test

1. Save the above content as `sample-invoice.txt`
2. Go to http://localhost:3000
3. Click on "Document Validator"
4. Upload the `sample-invoice.txt` file
5. Click "Validate Document"
6. See the AI validation results!

### Option 2: Enable Textract (For Production)

If you want to process actual images and PDFs, you need to:

1. **Enable Textract in AWS Console**
   - Go to AWS Console → Textract
   - Click "Get Started" or "Enable Service"
   - May require payment method on file

2. **Pricing** (as of 2024)
   - First 1,000 pages/month: Free
   - After that: ~$1.50 per 1,000 pages
   - Very affordable for testing

3. **No Code Changes Needed**
   - The Lambda function already has Textract code
   - It will automatically work once Textract is enabled

## What Works Now

✅ **Text Files (.txt)**
- Upload any .txt file with invoice content
- AI will extract fields and validate
- Full validation with recommendations

❌ **Images/PDFs (Requires Textract)**
- .jpg, .jpeg, .png, .pdf files
- Will show "Textract requires subscription" message
- Enable Textract to process these

## Demo Strategy

For your demo/presentation, you have two options:

### Strategy 1: Text File Demo (No Cost)
1. Create sample invoice text files
2. Show the upload and validation working
3. Explain that production would use Textract for images/PDFs
4. Mention it's a cost-saving measure for the demo

### Strategy 2: Enable Textract (Small Cost)
1. Enable Textract in AWS (free tier: 1,000 pages/month)
2. Upload actual invoice images
3. Show full OCR + validation working
4. More impressive demo, minimal cost

## Sample Test Files

I've created sample files you can use:

### Good Invoice (Should Pass)
```
COMMERCIAL INVOICE

Exporter: XYZ Exports Ltd
IEC Number: 1234567890
HSN Code: 12345678
Invoice Number: INV-2024-100
Invoice Date: 2024-03-08
Total Value: USD 10,000.00
Destination Country: United States
Product Description: Cotton Textiles
```

### Bad Invoice (Should Fail)
```
COMMERCIAL INVOICE

Exporter: ABC Company
IEC Number: 123  (WRONG - should be 10 digits)
HSN Code: 1234  (WRONG - should be 8 digits)
Invoice Date: 2025-12-31  (WRONG - future date)
Total Value: -5000  (WRONG - negative value)
```

## Expected Results

When you upload a text file, you should see:

1. **Extracted Fields**
   - Exporter Name
   - IEC Number
   - HSN Code
   - Invoice Date
   - Total Value
   - Destination Country

2. **Validation Status**
   - ✅ Valid (green)
   - ⚠️ Warning (yellow)
   - ❌ Error (red)

3. **Issues Found**
   - Missing fields
   - Invalid formats
   - Inconsistencies

4. **Recommendations**
   - How to fix each issue
   - Best practices

## Technical Details

The Lambda function checks the file extension:
- `.txt` → Read directly from S3 (works now)
- `.pdf`, `.jpg`, `.png` → Use Textract (requires subscription)

The code is already there, just needs Textract enabled!

## Cost Comparison

| Option | Cost | Pros | Cons |
|--------|------|------|------|
| Text Files | $0 | Free, works now | Less realistic demo |
| Textract | ~$0-5/month | Professional, handles real docs | Requires setup |

## Recommendation

For your demo: **Use text files** - it's free, works perfectly, and shows all the AI validation features. You can always enable Textract later for production.

## Questions?

If you want to enable Textract or need help creating test files, let me know!
