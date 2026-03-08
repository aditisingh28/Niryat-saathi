# NiryatSaathi - Quick Start Guide

This guide will help you deploy NiryatSaathi in under 30 minutes (assuming AWS account is ready).

## Prerequisites Checklist

- [ ] AWS account created
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Default region set to `ap-south-1` (Mumbai)
- [ ] Amazon Bedrock access enabled with Claude Sonnet 4.5
- [ ] Python 3.11+ installed
- [ ] Node.js 18+ installed

## Step 1: Enable Amazon Bedrock (CRITICAL)

**This must be done first!**

1. Go to AWS Console → Amazon Bedrock
2. Click "Model access" in left sidebar
3. Click "Request model access"
4. Find "Anthropic" → Check "Claude Sonnet 4.5"
5. Submit request
6. Wait for approval (1-2 hours)

**⚠️ The application will not work without Bedrock access!**

## Step 2: Clone and Setup

```bash
# Clone repository
git clone https://github.com/yourusername/niryatsaathi.git
cd niryatsaathi

# Verify AWS CLI is configured
aws sts get-caller-identity
```

## Step 3: Run Automated Setup

This single script will:
- Create all DynamoDB tables
- Create S3 bucket
- Create IAM roles
- Deploy Lambda functions
- Load HSN data

```bash
./scripts/setup-all.sh
```

**Expected time: 5-10 minutes**

## Step 4: Test HSN Classifier

```bash
./scripts/test-hsn-classifier.sh
```

You should see HSN code suggestions for test products.

## Step 5: Deploy Frontend (Optional)

```bash
cd frontend

# Install dependencies
npm install

# Create .env file
cp .env.example .env

# Edit .env and add your API Gateway URL (see Step 6)
# REACT_APP_API_URL=https://your-api-id.execute-api.ap-south-1.amazonaws.com/prod

# Build
npm run build

# Deploy to S3 (replace ACCOUNT_ID)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://niryatsaathi-frontend-${ACCOUNT_ID} --region ap-south-1
aws s3 sync build/ s3://niryatsaathi-frontend-${ACCOUNT_ID}/
```

## Step 6: Create API Gateway (Manual)

**Note:** This step requires manual configuration in AWS Console.

1. Go to AWS Console → API Gateway
2. Create REST API named "NiryatSaathi-API"
3. Create resource `/api/v1/classify-product`
4. Create POST method → Integrate with HSNClassifier Lambda
5. Enable CORS
6. Deploy to "prod" stage
7. Copy the Invoke URL

**Detailed instructions:** See `docs/deployment-guide.md` Phase 6

## Step 7: Test End-to-End

```bash
# Test via API Gateway
curl -X POST https://YOUR-API-ID.execute-api.ap-south-1.amazonaws.com/prod/api/v1/classify-product \
  -H "Content-Type: application/json" \
  -d '{"product_description":"handmade turmeric soap","language":"en","user_id":"test"}'
```

## Troubleshooting

### "Access Denied" when calling Bedrock
- Verify Bedrock access is approved in console
- Check IAM role has `bedrock:InvokeModel` permission
- Ensure using correct model ID: `anthropic.claude-sonnet-4-5-20241022`

### Lambda timeout errors
- Increase timeout to 30 seconds
- Increase memory to 512MB
- Check CloudWatch logs: `/aws/lambda/HSNClassifier`

### "Table not found" errors
- Verify tables exist: `aws dynamodb list-tables --region ap-south-1`
- Re-run setup: `./scripts/setup-all.sh`

### HSN data not loading
- Check S3 bucket exists
- Verify CSV file uploaded: `aws s3 ls s3://niryatsaathi-documents-${ACCOUNT_ID}/hsn-data/`
- Check Lambda logs: `aws logs tail /aws/lambda/HSNDataLoader --follow`

## Cost Estimate

**First 24 hours (hackathon):**
- Bedrock: ~₹500
- Other services: Free tier
- **Total: ~₹500**

**Monthly (1,000 users):**
- Bedrock: ~₹50,000
- Lambda: ~₹500
- DynamoDB: ~₹1,000
- Textract: ~₹7,500
- Other: ~₹1,200
- **Total: ~₹60,200/month**

## Next Steps

1. **Test with real products**: Use the 20 test products in `test-data/hsn-test-products.json`
2. **Measure accuracy**: Target >75% for HSN classification
3. **Deploy document validator**: Follow `docs/deployment-guide.md` Phase 4-5
4. **Set up monitoring**: Create CloudWatch dashboard
5. **Configure billing alerts**: Set alert for >₹1,000

## Support

- **Documentation**: See `docs/` folder
- **Issues**: Check CloudWatch logs
- **AWS Support**: Create support case if needed

## Success Criteria

- [ ] HSN Classifier returns results in <5 seconds
- [ ] Accuracy >75% on test dataset
- [ ] Frontend loads and displays results
- [ ] API Gateway CORS configured correctly
- [ ] CloudWatch logs show no errors
- [ ] Cost within budget (<₹1,000 for hackathon)

---

**Estimated total setup time: 30 minutes** (excluding Bedrock approval wait)

For detailed instructions, see:
- `docs/aws-setup.md` - AWS service configuration
- `docs/deployment-guide.md` - Step-by-step deployment
- `README.md` - Project overview
