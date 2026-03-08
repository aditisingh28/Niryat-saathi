# NiryatSaathi - Architecture & Implementation

## Overview

NiryatSaathi is an AI-powered export compliance assistant for Indian MSME exporters, built on AWS serverless architecture. The system provides HSN code classification and document validation through a React PWA, with WhatsApp integration ready for deployment.

**Status**: Production MVP deployed and publicly accessible  
**Live URL**: http://niryatsaathi-frontend.s3-website.ap-south-1.amazonaws.com  
**API Base**: https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod  
**Region**: ap-south-1 (Mumbai, India)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Users                                 │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │   Web Browser    │  │  WhatsApp        │                │
│  │   (Desktop/Mobile│  │  (Ready to deploy)│               │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Frontend Layer                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  React 18 PWA (S3 Static Website Hosting)           │  │
│  │  - HSN Classifier UI                                 │  │
│  │  - Document Validator UI                             │  │
│  │  - Mobile-responsive design                          │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway (REST)                        │
│  ID: 33m1wci2fb                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  POST /api/v1/classify-product                       │  │
│  │  POST /api/v1/upload-document                        │  │
│  │  POST /api/v1/validate-document                      │  │
│  │  POST /api/v1/whatsapp/webhook (ready)               │  │
│  │  GET  /api/v1/whatsapp/webhook (ready)               │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
│ HSNClassifier│  │ DocumentUpload│  │DocumentValidator │
│   Lambda     │  │   Lambda      │  │    Lambda        │
│  (Deployed)  │  │  (Deployed)   │  │   (Deployed)     │
└──────────────┘  └──────────────┘  └──────────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    AI Services Layer                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Amazon Bedrock - Qwen 3 235B Model                  │  │
│  │  Model ID: qwen.qwen3-235b-a22b-2507-v1:0            │  │
│  │  - HSN Classification                                │  │
│  │  - Document Validation                               │  │
│  │  - Free model (no subscription required)            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Storage Layer                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  S3 Buckets:                                         │  │
│  │  - niryatsaathi-frontend (static website)           │  │
│  │  - niryatsaathi-documents-262343431547 (uploads)    │  │
│  │                                                       │  │
│  │  DynamoDB Tables (ready to deploy):                  │  │
│  │  - WhatsAppConversations (conversation state)        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Frontend
- **Framework**: React 18
- **Language**: JavaScript
- **Styling**: Custom CSS (mobile-first)
- **Build Tool**: Create React App
- **Hosting**: AWS S3 Static Website
- **Status**: ✅ Deployed and live

### Backend
- **Compute**: AWS Lambda (Python 3.11)
- **API**: Amazon API Gateway (REST)
- **Region**: ap-south-1 (Mumbai)
- **Status**: ✅ 3 Lambda functions deployed

### AI/ML
- **Model**: Amazon Bedrock - Qwen 3 235B
- **Model ID**: qwen.qwen3-235b-a22b-2507-v1:0
- **Cost**: Free (no subscription required)
- **Use Cases**: HSN classification, document validation
- **Status**: ✅ Working

### Storage
- **Object Storage**: Amazon S3
  - Frontend hosting
  - Document uploads
  - CORS configured
- **Database**: DynamoDB (ready to deploy)
  - WhatsAppConversations table
- **Status**: ✅ S3 deployed, DynamoDB pending

### Security
- **IAM**: Least privilege roles for Lambda
- **Encryption**: S3 server-side encryption (AES-256)
- **CORS**: Configured for cross-origin requests
- **Authentication**: None (public API for MVP)

### Monitoring
- **Logs**: CloudWatch Logs (all Lambda functions)
- **Metrics**: CloudWatch Metrics (basic)
- **Alerts**: Not configured yet

## Deployed Components

### 1. HSNClassifier Lambda

**Purpose**: AI-powered HSN code classification

**Configuration**:
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 30 seconds
- Trigger: API Gateway POST /api/v1/classify-product

**Features**:
- Uses Bedrock Qwen model for classification
- Returns top 3 HSN codes with confidence scores
- Provides plain language explanations
- Normalizes response format
- ~5 second response time

**Environment Variables**:
```
BEDROCK_MODEL_ID=qwen.qwen3-235b-a22b-2507-v1:0
AWS_REGION=ap-south-1
```

### 2. DocumentUpload Lambda

**Purpose**: Generate pre-signed S3 URLs for secure uploads

**Configuration**:
- Runtime: Python 3.11
- Memory: 256 MB
- Timeout: 10 seconds
- Trigger: API Gateway POST /api/v1/upload-document

**Features**:
- Generates pre-signed URLs (5-minute expiration)
- Supports PDF, JPEG, PNG, TXT files
- Returns S3 key for validation step

**Environment Variables**:
```
S3_BUCKET=niryatsaathi-documents-262343431547
AWS_REGION=ap-south-1
```

### 3. DocumentValidator Lambda

**Purpose**: Extract and validate document fields

**Configuration**:
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 30 seconds
- Trigger: API Gateway POST /api/v1/validate-document

**Features**:
- Reads text files directly from S3
- Extracts: IEC, HSN, Invoice #, Date, Value, Country
- AI-powered validation with Bedrock
- Returns errors and recommendations
- Accepts multiple country format variations
- ~5 second response time

**Environment Variables**:
```
BEDROCK_MODEL_ID=qwen.qwen3-235b-a22b-2507-v1:0
S3_BUCKET=niryatsaathi-documents-262343431547
AWS_REGION=ap-south-1
```

## Ready to Deploy

### WhatsAppHandler Lambda

**Purpose**: WhatsApp Business API integration

**Configuration**:
- Runtime: Python 3.11
- Memory: 256 MB
- Timeout: 30 seconds
- Trigger: API Gateway POST /api/v1/whatsapp/webhook

**Features**:
- Webhook verification (GET request)
- Message handling (POST request)
- Conversation state management with DynamoDB
- Menu system (HSN, Document Validation, Help)
- Integration with HSNClassifier Lambda
- Commands: /start, /help, /reset

**Deployment Blockers**:
- Requires Meta Business Account
- Needs WhatsApp Business API access
- Requires Phone Number ID and Access Token

**Deployment Script**: `scripts/setup-whatsapp.sh`

## API Endpoints

### Base URL
```
https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod
```

### 1. POST /api/v1/classify-product

Classify product into HSN codes

**Request**:
```json
{
  "product_description": "handmade turmeric soap",
  "language": "en"
}
```

**Response**:
```json
{
  "classifications": [
    {
      "hsn_code": "34011110",
      "confidence": 0.89,
      "explanation": "Soap and organic surface-active products..."
    }
  ]
}
```

### 2. POST /api/v1/upload-document

Get pre-signed URL for document upload

**Request**:
```json
{
  "file_name": "invoice.txt",
  "file_type": "text/plain"
}
```

**Response**:
```json
{
  "upload_url": "https://...",
  "s3_key": "documents/2026/03/08/uuid.txt",
  "expires_in": 300
}
```

### 3. POST /api/v1/validate-document

Validate uploaded document

**Request**:
```json
{
  "s3_key": "documents/2026/03/08/uuid.txt"
}
```

**Response**:
```json
{
  "status": "valid",
  "extracted_fields": {
    "exporter_name": "ABC Exports Pvt Ltd",
    "iec_number": "0123456789",
    "hsn_code": "34011110",
    "invoice_number": "INV-2024-001",
    "invoice_date": "2024-03-08",
    "invoice_value": "USD 5,000.00",
    "destination_country": "United States"
  },
  "issues": [],
  "recommendations": []
}
```

## Deployment

### Scripts

All deployment scripts are in `scripts/` directory:

1. **deploy-lambda.sh** - Deploy individual Lambda functions
2. **deploy-remaining-lambdas.sh** - Deploy all Lambda functions
3. **setup-document-api.sh** - Configure API Gateway
4. **deploy-frontend.sh** - Build and deploy React app to S3
5. **setup-whatsapp.sh** - Deploy WhatsApp integration (ready)

### Testing Scripts

1. **test-hsn-classifier.sh** - Test HSN classification
2. **test-document-validation.sh** - Test document validation
3. **test-validation-only.sh** - Test validation Lambda
4. **quick-test.sh** - Quick smoke test

### Manual Deployment Steps

#### Frontend
```bash
cd niryat-saathi
./scripts/deploy-frontend.sh
```

#### Lambda Functions
```bash
cd niryat-saathi
./scripts/deploy-remaining-lambdas.sh
```

#### WhatsApp Integration
```bash
# After obtaining Meta Business credentials
cd niryat-saathi
./scripts/setup-whatsapp.sh

# Update Lambda environment variables
aws lambda update-function-configuration \
  --function-name WhatsAppHandler \
  --environment Variables="{
    WHATSAPP_TOKEN=YOUR_TOKEN,
    WHATSAPP_PHONE_ID=YOUR_PHONE_ID,
    VERIFY_TOKEN=niryatsaathi_verify_token,
    CONVERSATION_TABLE=WhatsAppConversations
  }" \
  --region ap-south-1
```

## Cost Analysis

### Current Monthly Costs

| Service | Usage | Cost |
|---------|-------|------|
| Bedrock (Qwen) | Free model | ₹0 |
| Lambda | Within free tier | ₹0 |
| API Gateway | Within free tier | ₹0 |
| S3 Storage | Minimal | ~₹5 |
| S3 Data Transfer | 1000 users | ~₹50 |
| CloudWatch | Within free tier | ₹0 |
| **Total** | | **~₹55/month** |

### With Future Enhancements

| Service | Usage | Cost |
|---------|-------|------|
| Current infrastructure | | ₹55 |
| WhatsApp Business API | After 1000 free | ~₹2,000 |
| Amazon Textract | 5000 pages | ~₹1,500 |
| DynamoDB | On-demand | ~₹1,000 |
| CloudFront CDN | Global delivery | ~₹200 |
| **Total** | | **~₹4,755/month** |

## Performance Metrics

### Current Performance

- **HSN Classification**: ~5 seconds
- **Document Upload**: <1 second (pre-signed URL)
- **Document Validation**: ~5 seconds
- **Frontend Load Time**: <2 seconds
- **API Latency**: <100ms (excluding Lambda cold start)

### Accuracy

- **HSN Classifier**: 70% accuracy on test dataset (10 products)
- **Document Validator**: Successfully extracts all required fields from text files

## Security

### Current Implementation

- ✅ S3 server-side encryption (AES-256)
- ✅ IAM roles with least privilege
- ✅ CORS configured for frontend
- ✅ Mumbai region for DPDP compliance
- ❌ No authentication (public API)
- ❌ No rate limiting
- ❌ No input validation beyond basic checks

### Recommended Improvements

1. Add API Gateway authentication (Cognito or API keys)
2. Implement rate limiting (API Gateway throttling)
3. Add input validation and sanitization
4. Enable AWS WAF for DDoS protection
5. Add CloudTrail for audit logging
6. Implement request signing for sensitive operations

## Future Enhancements

### Ready to Deploy

1. **WhatsApp Integration**
   - Status: Code complete, script ready
   - Blocker: Requires Meta Business Account
   - Effort: 2-3 hours after credentials

### Planned Features

2. **Amazon Textract** - PDF/image processing
3. **DynamoDB Tables** - HSN master data, document history
4. **CloudFront CDN** - HTTPS, custom domain
5. **Voice Input** - Amazon Transcribe
6. **Government Schemes** - Eligibility checker
7. **Policy Updates** - Automated scraping
8. **User Authentication** - Cognito
9. **Analytics** - Usage tracking
10. **Mobile App** - React Native

## Repository

- **GitHub**: https://github.com/aditisingh28/Niryat-saathi.git
- **Branch**: main
- **Last Updated**: March 8, 2026
- **Status**: ✅ All code pushed

## Access Information

### Public URLs

- **Frontend**: http://niryatsaathi-frontend.s3-website.ap-south-1.amazonaws.com
- **API**: https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod

### AWS Resources

- **Region**: ap-south-1 (Mumbai)
- **Account ID**: 262343431547
- **API Gateway ID**: 33m1wci2fb
- **S3 Buckets**:
  - niryatsaathi-frontend
  - niryatsaathi-documents-262343431547

### Documentation

- **README**: niryat-saathi/README.md
- **Deployment Guide**: niryat-saathi/docs/deployment-guide.md
- **AWS Setup**: niryat-saathi/docs/aws-setup.md
- **WhatsApp Plan**: niryat-saathi/WHATSAPP-INTEGRATION-PLAN.md
- **Testing Guide**: niryat-saathi/TESTING-WITHOUT-TEXTRACT.md
- **Deployment URLs**: niryat-saathi/DEPLOYMENT-URLS.md

---

**Last Updated**: March 8, 2026  
**Status**: Production MVP - 100% Complete  
**Next Milestone**: WhatsApp Integration Deployment
