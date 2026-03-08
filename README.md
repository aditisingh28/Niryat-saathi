# NiryatSaathi - AI-Powered Export Compliance Assistant

An AWS serverless application that helps Indian MSME exporters with HSN code classification and document validation using Amazon Bedrock and Textract.

## 🎯 Project Overview

NiryatSaathi simplifies export compliance for small business owners in India by providing:

1. **HSN Code Classifier**: AI-powered product classification into 8-digit HSN codes with confidence scores
2. **Document Validator**: Automated validation of commercial invoices using OCR and AI

### Target Users
- Small business exporters in tier 2/3 Indian cities
- Limited knowledge of trade terminology and HS codes
- Basic smartphone literacy

### Success Metrics
- HSN classification accuracy: >75%
- Document error detection: >90%
- Response time: <5 seconds (HSN), <15 seconds (documents)
- Total cost: <₹1,000 for 24-hour hackathon

## 🏗️ Architecture

### AWS Services Used

- **Amazon Bedrock** (Claude Sonnet 4.5) - AI classification and validation
- **Amazon Textract** - OCR for document processing
- **Amazon Translate** - Multilingual support (Hindi/English)
- **AWS Lambda** - Serverless compute (Python 3.11)
- **Amazon API Gateway** - REST API
- **Amazon DynamoDB** - NoSQL database
- **Amazon S3** - Object storage
- **AWS Step Functions** - Workflow orchestration
- **Amazon CloudWatch** - Logging and monitoring
- **Amazon CloudFront** - CDN for frontend
- **AWS Secrets Manager** - API key storage
- **AWS IAM** - Access control

### System Architecture

```
┌─────────────┐
│   User      │
│  (Browser)  │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│   CloudFront    │ ◄── React Frontend (S3)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  API Gateway    │ ◄── JWT Auth, Rate Limiting
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐ ┌──────────────┐
│  HSN    │ │  Document    │
│Classifier│ │  Validation  │
│ Lambda  │ │Step Functions│
└────┬────┘ └──────┬───────┘
     │             │
     ▼             ▼
┌─────────────────────────┐
│   Amazon Bedrock        │
│  (Claude Sonnet 4.5)    │
└─────────────────────────┘
     │             │
     ▼             ▼
┌──────────┐  ┌──────────┐
│ DynamoDB │  │ Textract │
└──────────┘  └──────────┘
```

## 📋 Prerequisites

### AWS Account Requirements
- Active AWS account
- Access to AWS Mumbai region (ap-south-1)
- AWS CLI installed and configured
- Sufficient permissions to create resources

### Required AWS Service Access
- Amazon Bedrock (Claude Sonnet 4.5 model access)
- Amazon Textract
- AWS Lambda
- Amazon DynamoDB
- Amazon S3
- Amazon API Gateway
- AWS Step Functions
- Amazon Translate
- Amazon CloudWatch
- AWS Secrets Manager
- AWS IAM

### Local Development Requirements
- Python 3.11+
- Node.js 18+ and npm
- AWS CLI v2
- Git

## 🚀 Quick Start Guide

**⚡ Fast Track:** See [QUICKSTART.md](QUICKSTART.md) for 30-minute setup guide

### Prerequisites

1. **AWS Account** with Mumbai region (ap-south-1) access
2. **AWS CLI** installed and configured (`aws configure`)
3. **Amazon Bedrock** access enabled with Claude Sonnet 4.5 (CRITICAL - request in console)
4. **Python 3.11+** and **Node.js 18+** installed

### One-Command Setup

```bash
# Clone repository
git clone https://github.com/yourusername/niryatsaathi.git
cd niryatsaathi

# Run automated setup (creates tables, buckets, roles, deploys Lambdas, loads data)
./scripts/setup-all.sh
```

This script will:
- ✓ Create all 4 DynamoDB tables
- ✓ Create S3 bucket with encryption
- ✓ Create IAM roles with proper permissions
- ✓ Deploy all 4 Lambda functions
- ✓ Load sample HSN data

**Time: 5-10 minutes**

### Test HSN Classifier

```bash
./scripts/test-hsn-classifier.sh
```

### Deploy Frontend (Optional)

```bash
cd frontend
npm install
npm run build

# Deploy to S3
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://niryatsaathi-frontend-${ACCOUNT_ID} --region ap-south-1
aws s3 sync build/ s3://niryatsaathi-frontend-${ACCOUNT_ID}/
```

### Manual Steps Required

1. **API Gateway**: Create REST API and connect to Lambda (see [docs/deployment-guide.md](docs/deployment-guide.md))
2. **Frontend Config**: Update `.env` with API Gateway URL
3. **CloudFront**: Create distribution for frontend (optional)

## 📁 Project Structure

```
niryatsaathi/
├── README.md
├── docs/
│   ├── aws-setup.md              # Detailed AWS setup guide
│   ├── deployment-guide.md       # Step-by-step deployment
│   ├── api-reference.md          # API documentation
│   ├── architecture.md           # Architecture details
│   └── troubleshooting.md        # Common issues and solutions
├── lambda/
│   ├── hsn-classifier/
│   │   ├── lambda_function.py
│   │   ├── requirements.txt
│   │   └── README.md
│   ├── document-processor/
│   │   ├── lambda_function.py
│   │   ├── requirements.txt
│   │   └── README.md
│   ├── document-validator/
│   │   ├── lambda_function.py
│   │   ├── requirements.txt
│   │   └── README.md
│   └── hsn-data-loader/
│       ├── lambda_function.py
│       ├── requirements.txt
│       └── README.md
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── services/
│   │   └── App.js
│   ├── package.json
│   └── README.md
├── infrastructure/
│   ├── dynamodb/
│   │   └── tables.json
│   ├── s3/
│   │   └── bucket-config.json
│   ├── api-gateway/
│   │   └── api-definition.json
│   ├── step-functions/
│   │   └── document-workflow.json
│   └── iam/
│       └── policies.json
├── scripts/
│   ├── deploy-dynamodb.sh
│   ├── deploy-s3.sh
│   ├── deploy-lambda.sh
│   ├── deploy-api-gateway.sh
│   ├── deploy-step-functions.sh
│   ├── deploy-frontend.sh
│   └── download-hsn-data.sh
├── test-data/
│   ├── hsn-test-products.json    # 20 test products
│   ├── sample-invoices/          # Sample documents
│   └── ground-truth.json         # Expected results
└── .gitignore
```

## 📖 Documentation

- [AWS Setup Guide](docs/aws-setup.md) - Complete AWS account and service setup
- [Deployment Guide](docs/deployment-guide.md) - Step-by-step deployment instructions
- [API Reference](docs/api-reference.md) - API endpoints and contracts
- [Architecture Guide](docs/architecture.md) - Detailed architecture documentation
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## 🔐 Security & Compliance

### DPDP Compliance
- All data stored in Mumbai region (ap-south-1)
- 30-day auto-deletion for documents (S3 lifecycle + DynamoDB TTL)
- PII stripping before sending to Bedrock
- Encryption at rest for all storage

### Security Features
- IAM roles with least privilege
- No hardcoded credentials (AWS Secrets Manager)
- S3 buckets with no public access
- Pre-signed URLs for document uploads
- API Gateway JWT authentication
- Rate limiting (100 requests/minute)

## 💰 Cost Estimation

### Hackathon (24 hours)
- Bedrock: ~₹500
- Other services: Free tier
- **Total: ~₹500**

### Production (1,000 users/month)
- Bedrock: ~₹50,000
- Lambda: ~₹500
- DynamoDB: ~₹1,000
- Textract: ~₹7,500
- Other: ~₹1,200
- **Total: ~₹60,200/month**

See [docs/cost-optimization.md](docs/cost-optimization.md) for cost reduction strategies.

## 🧪 Testing

### Test Dataset
20 common export products with verified HSN codes:
- Handmade turmeric soap → 34011190
- Cotton bedsheets → 63022100
- Frozen mango pulp → 0811909090
- Basmati rice → 10063020
- And 16 more...

### Running Tests

```bash
# Test HSN classifier accuracy
python scripts/test-hsn-accuracy.py

# Test document validator
python scripts/test-document-validator.py

# Run all tests
./scripts/run-all-tests.sh
```

## 📊 Monitoring

### CloudWatch Dashboard
- Lambda invocations and errors
- API Gateway requests and latency
- DynamoDB read/write capacity
- Bedrock token usage

### Alarms
- Lambda error rate > 5%
- API Gateway 5xx rate > 1%
- Lambda duration > 25 seconds
- Estimated cost > ₹1,000

## 🤝 Contributing

This is a hackathon project. For improvements:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- CBIC for HSN code master data
- AWS for serverless infrastructure
- Anthropic for Claude AI model

## 📞 Support

For issues and questions:
- Create an issue on GitHub
- Email: support@niryatsaathi.in
- Documentation: https://docs.niryatsaathi.in

## 🎥 Demo

Watch the demo video: [YouTube Link]

---

**Disclaimer**: This is AI-assisted decision support, not legal advice. Always verify with customs brokers for critical export decisions.
