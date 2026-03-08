#!/bin/bash

# Deploy NiryatSaathi Frontend to AWS S3 + CloudFront
# This script builds the React app and deploys it to S3 with CloudFront CDN

set -e

echo "========================================="
echo "NiryatSaathi Frontend Deployment"
echo "========================================="
echo ""

# Configuration
REGION="ap-south-1"
BUCKET_NAME="niryatsaathi-frontend"
CLOUDFRONT_COMMENT="NiryatSaathi PWA"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Building React app${NC}"
echo ""

cd frontend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build production bundle
echo "Building production bundle..."
npm run build

cd ..

echo -e "${GREEN}✅ Build complete${NC}"
echo ""

echo -e "${YELLOW}Step 2: Creating S3 bucket${NC}"
echo ""

# Create S3 bucket
aws s3 mb s3://$BUCKET_NAME --region $REGION 2>/dev/null || echo "Bucket already exists"

# Configure bucket for static website hosting
aws s3 website s3://$BUCKET_NAME \
  --index-document index.html \
  --error-document index.html

echo -e "${GREEN}✅ S3 bucket configured${NC}"
echo ""

echo -e "${YELLOW}Step 3: Setting bucket policy for public access${NC}"
echo ""

# Create bucket policy for public read access
cat > /tmp/bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF

# Disable block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# Apply bucket policy
aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file:///tmp/bucket-policy.json

rm /tmp/bucket-policy.json

echo -e "${GREEN}✅ Bucket policy applied${NC}"
echo ""

echo -e "${YELLOW}Step 4: Uploading files to S3${NC}"
echo ""

# Upload build files to S3
aws s3 sync frontend/build/ s3://$BUCKET_NAME/ \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html" \
  --exclude "service-worker.js" \
  --exclude "manifest.json"

# Upload index.html with no-cache (for SPA routing)
aws s3 cp frontend/build/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "no-cache, no-store, must-revalidate" \
  --content-type "text/html"

# Upload service worker with no-cache
if [ -f "frontend/build/service-worker.js" ]; then
  aws s3 cp frontend/build/service-worker.js s3://$BUCKET_NAME/service-worker.js \
    --cache-control "no-cache, no-store, must-revalidate" \
    --content-type "application/javascript"
fi

# Upload manifest with no-cache
if [ -f "frontend/build/manifest.json" ]; then
  aws s3 cp frontend/build/manifest.json s3://$BUCKET_NAME/manifest.json \
    --cache-control "no-cache, no-store, must-revalidate" \
    --content-type "application/json"
fi

echo -e "${GREEN}✅ Files uploaded${NC}"
echo ""

echo -e "${YELLOW}Step 5: Creating CloudFront distribution (optional)${NC}"
echo ""

# Check if CloudFront distribution exists
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='$CLOUDFRONT_COMMENT'].Id" --output text 2>/dev/null || echo "")

if [ -z "$DISTRIBUTION_ID" ]; then
    echo "Creating new CloudFront distribution..."
    echo "This may take 15-20 minutes to deploy globally."
    echo ""
    
    # Create CloudFront distribution config
    cat > /tmp/cloudfront-config.json <<EOF
{
  "CallerReference": "niryatsaathi-$(date +%s)",
  "Comment": "$CLOUDFRONT_COMMENT",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-$BUCKET_NAME",
        "DomainName": "$BUCKET_NAME.s3-website.$REGION.amazonaws.com",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$BUCKET_NAME",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000,
    "Compress": true
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "PriceClass": "PriceClass_All"
}
EOF

    DISTRIBUTION_ID=$(aws cloudfront create-distribution \
      --distribution-config file:///tmp/cloudfront-config.json \
      --query 'Distribution.Id' \
      --output text 2>/dev/null || echo "")
    
    rm /tmp/cloudfront-config.json
    
    if [ -n "$DISTRIBUTION_ID" ]; then
        echo -e "${GREEN}✅ CloudFront distribution created: $DISTRIBUTION_ID${NC}"
        echo "Note: It will take 15-20 minutes to deploy globally"
    else
        echo -e "${YELLOW}⚠️  CloudFront creation skipped (optional)${NC}"
    fi
else
    echo "CloudFront distribution already exists: $DISTRIBUTION_ID"
    echo "Invalidating cache..."
    aws cloudfront create-invalidation \
      --distribution-id $DISTRIBUTION_ID \
      --paths "/*" > /dev/null
    echo -e "${GREEN}✅ Cache invalidated${NC}"
fi

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo -e "${BLUE}S3 Website URL:${NC}"
echo "http://$BUCKET_NAME.s3-website.$REGION.amazonaws.com"
echo ""

if [ -n "$DISTRIBUTION_ID" ]; then
    CLOUDFRONT_DOMAIN=$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.DomainName' --output text)
    echo -e "${BLUE}CloudFront URL (HTTPS):${NC}"
    echo "https://$CLOUDFRONT_DOMAIN"
    echo ""
fi

echo -e "${GREEN}Your PWA is now publicly accessible!${NC}"
echo ""
echo "Next steps:"
echo "1. Test the URL in your browser"
echo "2. Share with users"
echo "3. (Optional) Add custom domain with Route53"
echo ""
