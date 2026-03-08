# Test Data for Document Validator

This folder contains sample invoice files you can use to test the Document Validator feature.

## Available Test Files

### 1. sample-invoice-good.txt
**Purpose**: Test successful validation
**Content**: Complete, valid commercial invoice for turmeric soap export
**Expected Result**: ✅ Should pass validation with minimal warnings

**Details:**
- Valid IEC: 0123456789 (10 digits)
- Valid HSN: 34011110 (8 digits)
- Valid date: 2024-03-08 (not in future)
- Complete fields: All required information present

### 2. sample-invoice-errors.txt
**Purpose**: Test error detection
**Content**: Invoice with multiple validation errors
**Expected Result**: ❌ Should fail validation with multiple errors

**Intentional Errors:**
- Invalid IEC: "123" (should be 10 digits)
- Invalid HSN: "1234" (should be 8 digits)
- Future date: 2025-12-31 (in the future)
- Negative value: -5000.00 (should be positive)
- Missing invoice number
- Incomplete buyer information

### 3. sample-invoice-basmati-rice.txt
**Purpose**: Test with realistic export scenario
**Content**: Complete invoice for basmati rice export to UAE
**Expected Result**: ✅ Should pass validation

**Details:**
- Product: Basmati Rice (1121 variety)
- Destination: UAE
- Value: USD 25,000
- Includes special certificates
- Complete documentation

## How to Use

### From the PWA (http://localhost:3000)

1. Go to "Document Validator" page
2. Click "Choose File" or drag and drop
3. Select one of these .txt files
4. Click "Validate Document"
5. Review the AI validation results

### From Command Line

```bash
# Test with good invoice
./scripts/test-validation-only.sh

# Or manually test
aws s3 cp test-data/sample-invoice-good.txt s3://niryatsaathi-documents-262343431547/test/invoice.txt
curl -X POST https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod/api/v1/validate-document \
  -H "Content-Type: application/json" \
  -d '{"s3_key": "test/invoice.txt", "file_id": "test-123"}'
```

## Expected Validation Results

### Good Invoice
```json
{
  "status": "valid" or "warning",
  "extracted_fields": {
    "exporter_name": "ABC Exports Pvt Ltd",
    "iec_number": "0123456789",
    "hsn_code": "34011110",
    "invoice_date": "2024-03-08",
    "invoice_value": "USD 5,000.00"
  },
  "issues": [],
  "recommendations": []
}
```

### Invoice with Errors
```json
{
  "status": "error",
  "issues": [
    "Invalid IEC format: must be 10 digits",
    "Invalid HSN format: must be 8 digits",
    "Future date detected",
    "Negative invoice value"
  ],
  "recommendations": [
    "Correct IEC number to 10 digits",
    "Use proper 8-digit HSN code",
    "Verify invoice date",
    "Check invoice value calculation"
  ]
}
```

## Creating Your Own Test Files

### Format Requirements

1. **Plain text file** (.txt extension)
2. **Include key fields:**
   - Exporter name
   - IEC Number (10 digits)
   - HSN Code (8 digits)
   - Invoice Number
   - Invoice Date (YYYY-MM-DD format)
   - Total Value (with currency)
   - Destination Country
   - Product Description

3. **Use clear labels:**
   ```
   Field Name: Field Value
   ```

### Example Template

```
COMMERCIAL INVOICE

Exporter: [Your Company Name]
IEC Number: [10 digits]
Address: [Full Address]

Invoice Number: [INV-XXXX-XXX]
Invoice Date: [YYYY-MM-DD]
HSN Code: [8 digits]

Product Description: [Product Name]
Quantity: [Number] units
Unit Price: [Currency] [Amount]
Total Value: [Currency] [Total]

Destination Country: [Country Name]
Buyer: [Buyer Company Name]
Buyer Address: [Buyer Address]

Payment Terms: [Terms]
Shipping Terms: [Terms]
```

## Why Text Files?

Amazon Textract (which processes images and PDFs) requires an AWS subscription. Text files work without any subscription and demonstrate all the AI validation features:

- ✅ Field extraction
- ✅ Format validation
- ✅ Error detection
- ✅ AI-powered recommendations
- ✅ Consistency checks

For production use, enable Textract to process actual invoice images and PDFs.

## Tips for Demo

1. **Start with good invoice** - Show successful validation
2. **Then show error detection** - Upload invoice with errors
3. **Explain the AI** - Point out how it identifies issues
4. **Show recommendations** - Highlight actionable advice
5. **Mention Textract** - Explain it works with images too (with subscription)

## Need More Test Cases?

Create additional test files for:
- Different product types (textiles, handicrafts, food)
- Different destinations (USA, EU, Middle East)
- Various error scenarios
- Edge cases (missing fields, unusual formats)

Just follow the template and save as .txt files!
