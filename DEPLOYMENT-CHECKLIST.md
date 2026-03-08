# NiryatSaathi Deployment Checklist

Use this checklist to track your deployment progress.

## Phase 1: Prerequisites ⏱️ 15 minutes (+ 1-2 hours Bedrock approval)

- [ ] AWS account created
- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS CLI configured (`aws configure`)
- [ ] Default region set to `ap-south-1`
- [ ] Python 3.11+ installed (`python3 --version`)
- [ ] Node.js 18+ installed (`node --version`)
- [ ] **CRITICAL:** Amazon Bedrock access requested
- [ ] **CRITICAL:** Claude Sonnet 4.5 access approved (check email)
- [ ] Repository cloned (`git clone ...`)

## Phase 2: Automated Setup ⏱️ 5-10 minutes

- [ ] Run `./scripts/setup-all.sh`
- [ ] Verify 4 DynamoDB tables created
- [ ] Verify S3 bucket created
- [ ] Verify 3 IAM roles created
- [ ] Verify 4 Lambda functions deployed
- [ ] Verify HSN data loaded (20 items in HSNCodeMaster table)

**Verification commands:**
```bash
aws dynamodb list-tables --region ap-south-1
aws s3 ls | grep niryatsaathi
aws iam list-roles | grep NiryatSaathi
aws lambda list-functions --region ap-south-1 | grep HSN
```

## Phase 3: Testing ⏱️ 5 minutes

- [ ] Run `./scripts/test-hsn-classifier.sh`
- [ ] Verify HSN codes returned
- [ ] Verify confidence scores present
- [ ] Verify response time <5 seconds
- [ ] Check CloudWatch logs for errors

**Test command:**
```bash
./scripts/test-hsn-classifier.sh
```

## Phase 4: API Gateway Setup ⏱️ 10 minutes (Manual)

- [ ] Go to AWS Console → API Gateway
- [ ] Create REST API: "NiryatSaathi-API"
- [ ] Create resource: `/api`
- [ ] Create resource: `/api/v1`
- [ ] Create resource: `/api/v1/classify-product`
- [ ] Create POST method
- [ ] Integration type: Lambda Function
- [ ] Select HSNClassifier function
- [ ] Enable Lambda Proxy Integration
- [ ] Enable CORS (Actions → Enable CORS)
- [ ] Deploy API to "prod" stage
- [ ] Copy Invoke URL
- [ ] Test API with curl

**Test command:**
```bash
curl -X POST https://YOUR-API-ID.execute-api.ap-south-1.amazonaws.com/prod/api/v1/classify-product \
  -H "Content-Type: application/json" \
  -d '{"product_description":"handmade turmeric soap","language":"en","user_id":"test"}'
```

## Phase 5: Frontend Deployment ⏱️ 10 minutes (Optional)

- [ ] `cd frontend`
- [ ] `npm install`
- [ ] Create `.env` file
- [ ] Add API Gateway URL to `.env`
- [ ] `npm run build`
- [ ] Create S3 bucket for frontend
- [ ] Upload build files to S3
- [ ] Enable static website hosting
- [ ] Test frontend URL

**Commands:**
```bash
cd frontend
npm install
cp .env.example .env
# Edit .env with your API URL
npm run build

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 mb s3://niryatsaathi-frontend-${ACCOUNT_ID} --region ap-south-1
aws s3 sync build/ s3://niryatsaathi-frontend-${ACCOUNT_ID}/
aws s3 website s3://niryatsaathi-frontend-${ACCOUNT_ID} \
  --index-document index.html \
  --error-document index.html
```

## Phase 6: Monitoring Setup ⏱️ 5 minutes

- [ ] Go to CloudWatch → Dashboards
- [ ] Create dashboard: "NiryatSaathi"
- [ ] Add Lambda metrics (invocations, errors, duration)
- [ ] Add DynamoDB metrics (read/write capacity)
- [ ] Create alarm for Lambda errors
- [ ] Create alarm for estimated charges >₹1,000
- [ ] Set up SNS topic for alerts

## Phase 7: Security Verification ⏱️ 5 minutes

- [ ] Verify S3 bucket has no public access
- [ ] Verify DynamoDB encryption enabled
- [ ] Verify IAM roles use least privilege
- [ ] Verify no hardcoded credentials in code
- [ ] Verify CloudWatch logging enabled
- [ ] Verify API Gateway rate limiting configured

**Verification commands:**
```bash
aws s3api get-public-access-block --bucket niryatsaathi-documents-${ACCOUNT_ID}
aws dynamodb describe-table --table-name HSNCodeMaster --query 'Table.SSEDescription'
```

## Phase 8: Accuracy Testing ⏱️ 15 minutes

- [ ] Test all 20 products in `test-data/hsn-test-products.json`
- [ ] Calculate accuracy (correct HSN in top 3 results)
- [ ] Target: >75% accuracy
- [ ] Measure average response time
- [ ] Target: <5 seconds
- [ ] Test with Hindi descriptions
- [ ] Document results

**Test script:**
```bash
# Create test script or test manually
for product in $(cat test-data/hsn-test-products.json | jq -r '.[].product_description'); do
  echo "Testing: $product"
  # Call API and check results
done
```

## Phase 9: Cost Monitoring ⏱️ 5 minutes

- [ ] Go to AWS Billing Dashboard
- [ ] Check current charges
- [ ] Verify billing alert configured
- [ ] Review service-wise costs
- [ ] Estimate monthly costs
- [ ] Document cost breakdown

## Phase 10: Documentation ⏱️ 5 minutes

- [ ] Update README with actual API URL
- [ ] Document any issues encountered
- [ ] Create demo video (optional)
- [ ] Take screenshots of working app
- [ ] Document accuracy results
- [ ] Create GitHub repository
- [ ] Push code to GitHub

## Success Criteria

### Must Achieve ✅
- [ ] HSN classification accuracy: >75%
- [ ] Response time: <5 seconds
- [ ] Working Lambda functions
- [ ] API Gateway configured
- [ ] No errors in CloudWatch logs
- [ ] Cost: <₹1,000 for 24 hours

### Nice to Have 🎯
- [ ] Frontend deployed and working
- [ ] Document validator implemented
- [ ] CloudWatch dashboard created
- [ ] Demo video recorded
- [ ] GitHub repository public

## Troubleshooting Checklist

If something doesn't work:

- [ ] Check CloudWatch logs: `/aws/lambda/HSNClassifier`
- [ ] Verify Bedrock access approved
- [ ] Verify IAM role permissions
- [ ] Check API Gateway CORS configuration
- [ ] Verify Lambda environment variables
- [ ] Check DynamoDB table names match
- [ ] Verify S3 bucket exists
- [ ] Check Lambda timeout settings
- [ ] Verify Lambda memory settings
- [ ] Test with simple curl command first

## Time Estimate

| Phase | Time | Can Skip? |
|-------|------|-----------|
| Prerequisites | 15 min + wait | No |
| Automated Setup | 10 min | No |
| Testing | 5 min | No |
| API Gateway | 10 min | No |
| Frontend | 10 min | Yes |
| Monitoring | 5 min | Yes |
| Security | 5 min | No |
| Accuracy Testing | 15 min | No |
| Cost Monitoring | 5 min | Yes |
| Documentation | 5 min | Yes |
| **Total** | **85 min** | |

**Minimum viable deployment: 45 minutes** (excluding Bedrock approval wait)

## Quick Commands Reference

```bash
# Check AWS identity
aws sts get-caller-identity

# List DynamoDB tables
aws dynamodb list-tables --region ap-south-1

# List Lambda functions
aws lambda list-functions --region ap-south-1

# Check Lambda logs
aws logs tail /aws/lambda/HSNClassifier --follow

# Test Lambda directly
aws lambda invoke \
  --function-name HSNClassifier \
  --region ap-south-1 \
  --payload '{"body":"{\"product_description\":\"soap\",\"language\":\"en\"}"}' \
  response.json

# Check DynamoDB item count
aws dynamodb scan --table-name HSNCodeMaster --select COUNT --region ap-south-1

# Check S3 bucket
aws s3 ls s3://niryatsaathi-documents-${ACCOUNT_ID}/hsn-data/
```

---

**Print this checklist and check off items as you complete them!**

Good luck! 🚀
