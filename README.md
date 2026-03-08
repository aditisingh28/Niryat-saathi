# NiryatSaathi - AI-Powered Export Assistant 🚀

An intelligent platform helping Indian MSME exporters with HSN code classification and document validation using AWS Bedrock AI.

## 🌟 Features

### 1. HSN Code Classifier
- **AI-Powered Classification**: Get top 3 HSN code suggestions for any product
- **Confidence Scoring**: Visual confidence indicators (98%, 85%, 70%)
- **Detailed Explanations**: Understand why each HSN code applies
- **Multilingual Support**: Works in English and Hindi
- **Fast & Accurate**: Results in under 5 seconds

### 2. Beautiful UI
- **Recommendation Banner**: Highlights the best HSN code match
- **Progress Bars**: Visual confidence representation
- **Ranked Results**: Clear #1, #2, #3 ranking system
- **Mobile Responsive**: Works on all devices
- **Color-Coded**: Green (high), Yellow (medium), Red (low confidence)

## 🏗️ Architecture

- **Frontend**: React.js with modern CSS
- **Backend**: AWS Lambda (Python 3.11)
- **AI Model**: Qwen 3 (235B) via AWS Bedrock
- **API**: AWS API Gateway (REST)
- **Region**: ap-south-1 (Mumbai)

## 🚀 Live Demo

- **Frontend**: http://localhost:3000 (development)
- **API Endpoint**: https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod

## 🛠️ Setup Instructions

### Prerequisites
- Node.js 16+ and npm
- AWS Account with Bedrock access
- AWS CLI configured

### Frontend Setup
```bash
cd frontend
npm install
npm start
```

### Lambda Deployment
```bash
cd scripts
./deploy-lambda.sh
```

## 🧪 Testing

Try these example products:
- Handmade turmeric soap
- Cotton bedsheets
- Basmati rice
- Wooden toys

## 📊 API Response Format

```json
{
  "product": "handmade soap",
  "classifications": [
    {
      "hsn_code": "34011110",
      "confidence": 0.96,
      "explanation": "This code specifically covers..."
    }
  ],
  "model_used": "qwen.qwen3-235b-a22b-2507-v1:0"
}
```

## 🔧 Configuration

Update `frontend/.env`:
```
REACT_APP_API_URL=https://your-api-gateway-url.amazonaws.com/prod
```

## 📝 Project Status

- ✅ HSN Classifier with AI
- ✅ Beautiful responsive UI
- ✅ API Gateway integration
- ✅ Confidence visualization
- 🚧 Document Validator (coming soon)
- 🚧 Multilingual support (coming soon)

## 🤝 Contributing

This project was built for AI For Bharat hackathon. Contributions welcome!

## 📄 License

MIT License

## 👥 Team

Built with ❤️ for Indian MSME Exporters

---

⚠️ **Disclaimer**: This is AI-assisted decision support, not legal advice. Always verify HSN codes with customs brokers for critical export decisions.


## Testing

### HSN Classifier Tests
```bash
# Quick test (5 products)
./scripts/quick-test.sh

# Comprehensive test (10 products)
./scripts/test-10-products.sh

# Full test suite (20 products)
./scripts/test-all-products.sh
```

### Document Validator Tests

**Important**: Amazon Textract requires a subscription to process images and PDFs. For testing without Textract, use the provided text files.

#### Using Sample Text Files (No Subscription Needed)

We've provided sample invoice files in `test-data/` that you can use:

1. **sample-invoice-good.txt** - Valid invoice (should pass)
2. **sample-invoice-errors.txt** - Invoice with errors (should fail)
3. **sample-invoice-basmati-rice.txt** - Realistic export scenario

**How to test:**
1. Go to http://localhost:3000
2. Click "Document Validator"
3. Upload one of the sample .txt files from `test-data/`
4. Click "Validate Document"
5. See AI validation results!

See `test-data/README.md` for detailed instructions.

#### Command Line Testing
```bash
# Test document validation API
./scripts/test-document-validation.sh

# Test complete upload flow
./scripts/test-validation-only.sh

# Test frontend flow simulation
./scripts/test-frontend-upload.sh
```

### Enabling Textract (Optional)

To process actual images and PDFs:
1. Go to AWS Console → Textract
2. Enable the service (free tier: 1,000 pages/month)
3. No code changes needed - it will work automatically

See `TESTING-WITHOUT-TEXTRACT.md` for more details.

## Documentation

- `README.md` - This file
- `TESTING-WITHOUT-TEXTRACT.md` - Guide for testing without Textract subscription
- `test-data/README.md` - Sample invoice files and usage
- `TEST-RESULTS.md` - HSN classifier test results
- `DOCUMENT-VALIDATION-TEST-RESULTS.md` - Document validator test results
- `CORS-FIX.md` - CORS configuration fixes
- `S3-CORS-FIX.md` - S3 bucket CORS setup
- `FINAL-STATUS.md` - Complete project status
- `PROJECT-SUMMARY.md` - Project overview
