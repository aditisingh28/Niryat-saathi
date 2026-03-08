#!/bin/bash

# Create IAM roles for NiryatSaathi Lambda functions
# Usage: ./scripts/create-iam-roles.sh

set -e

REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "========================================="
echo "Creating IAM Roles for NiryatSaathi"
echo "========================================="
echo "Account: $ACCOUNT_ID"
echo ""

# Create trust policy for Lambda
cat > /tmp/lambda-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create HSNClassifier Role
echo "Creating HSNClassifier Role..."
aws iam create-role \
    --role-name NiryatSaathi-HSNClassifier-Role \
    --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
    2>/dev/null || echo "Role already exists"

# Attach policies to HSNClassifier Role
aws iam attach-role-policy \
    --role-name NiryatSaathi-HSNClassifier-Role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create inline policy for Bedrock
cat > /tmp/bedrock-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": "arn:aws:bedrock:${REGION}::foundation-model/*"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name NiryatSaathi-HSNClassifier-Role \
    --policy-name BedrockAccess \
    --policy-document file:///tmp/bedrock-policy.json

# Create inline policy for DynamoDB
cat > /tmp/dynamodb-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/HSNCodeMaster",
        "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/HSNCodeMaster/*",
        "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/AuditLog",
        "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/UserProfiles"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name NiryatSaathi-HSNClassifier-Role \
    --policy-name DynamoDBAccess \
    --policy-document file:///tmp/dynamodb-policy.json

# Create inline policy for Translate
cat > /tmp/translate-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "translate:TranslateText"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name NiryatSaathi-HSNClassifier-Role \
    --policy-name TranslateAccess \
    --policy-document file:///tmp/translate-policy.json

echo "✓ HSNClassifier Role created"

# Create DocumentProcessor Role
echo "Creating DocumentProcessor Role..."
aws iam create-role \
    --role-name NiryatSaathi-DocumentProcessor-Role \
    --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
    2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
    --role-name NiryatSaathi-DocumentProcessor-Role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create inline policy for Textract
cat > /tmp/textract-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "textract:AnalyzeDocument",
        "textract:DetectDocumentText"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name NiryatSaathi-DocumentProcessor-Role \
    --policy-name TextractAccess \
    --policy-document file:///tmp/textract-policy.json

# Create inline policy for S3
cat > /tmp/s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::niryatsaathi-documents-${ACCOUNT_ID}/*"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name NiryatSaathi-DocumentProcessor-Role \
    --policy-name S3Access \
    --policy-document file:///tmp/s3-policy.json

echo "✓ DocumentProcessor Role created"

# Create DocumentValidator Role
echo "Creating DocumentValidator Role..."
aws iam create-role \
    --role-name NiryatSaathi-DocumentValidator-Role \
    --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
    2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
    --role-name NiryatSaathi-DocumentValidator-Role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam put-role-policy \
    --role-name NiryatSaathi-DocumentValidator-Role \
    --policy-name BedrockAccess \
    --policy-document file:///tmp/bedrock-policy.json

# Create inline policy for DocumentHistory table
cat > /tmp/dynamodb-doc-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/DocumentHistory"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name NiryatSaathi-DocumentValidator-Role \
    --policy-name DynamoDBAccess \
    --policy-document file:///tmp/dynamodb-doc-policy.json

echo "✓ DocumentValidator Role created"

# Clean up temp files
rm /tmp/lambda-trust-policy.json
rm /tmp/bedrock-policy.json
rm /tmp/dynamodb-policy.json
rm /tmp/translate-policy.json
rm /tmp/textract-policy.json
rm /tmp/s3-policy.json
rm /tmp/dynamodb-doc-policy.json

echo ""
echo "========================================="
echo "All IAM roles created successfully!"
echo "========================================="
echo ""
echo "Created roles:"
echo "- NiryatSaathi-HSNClassifier-Role"
echo "- NiryatSaathi-DocumentProcessor-Role"
echo "- NiryatSaathi-DocumentValidator-Role"
echo ""
echo "Next step: Deploy Lambda functions"
echo "./scripts/deploy-lambda.sh"
