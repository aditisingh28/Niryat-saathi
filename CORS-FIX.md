# CORS Fix for Document Validator

## Issue
When uploading images from the PWA frontend, the browser was getting a CORS error because the API Gateway didn't have OPTIONS method configured for CORS preflight requests.

## Error Symptoms
- Browser console shows CORS error
- OPTIONS request returns 403 Forbidden
- File upload fails from frontend (but works from curl/Postman)

## Root Cause
API Gateway endpoints `/api/v1/upload-document` and `/api/v1/validate-document` were missing:
1. OPTIONS method
2. CORS headers in OPTIONS response

## Solution Applied

### 1. Added OPTIONS Method to Both Endpoints

```bash
# For upload-document endpoint
aws apigateway put-method \
  --rest-api-id 33m1wci2fb \
  --resource-id cae5v7 \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region ap-south-1

# For validate-document endpoint  
aws apigateway put-method \
  --rest-api-id 33m1wci2fb \
  --resource-id h9hhwo \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region ap-south-1
```

### 2. Added Mock Integration

```bash
aws apigateway put-integration \
  --rest-api-id 33m1wci2fb \
  --resource-id <RESOURCE_ID> \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
  --region ap-south-1
```

### 3. Added Method Response

```bash
aws apigateway put-method-response \
  --rest-api-id 33m1wci2fb \
  --resource-id <RESOURCE_ID> \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": false,
    "method.response.header.Access-Control-Allow-Methods": false,
    "method.response.header.Access-Control-Allow-Origin": false
  }' \
  --region ap-south-1
```

### 4. Added Integration Response with CORS Headers

```bash
aws apigateway put-integration-response \
  --rest-api-id 33m1wci2fb \
  --resource-id <RESOURCE_ID> \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''",
    "method.response.header.Access-Control-Allow-Methods": "'\''POST,OPTIONS'\''",
    "method.response.header.Access-Control-Allow-Origin": "'\''*'\''"
  }' \
  --region ap-south-1
```

### 5. Deployed Changes

```bash
aws apigateway create-deployment \
  --rest-api-id 33m1wci2fb \
  --stage-name prod \
  --region ap-south-1
```

## Verification

Test CORS preflight:
```bash
curl -X OPTIONS 'https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod/api/v1/upload-document' \
  -H 'Origin: http://localhost:3000' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type' \
  -i
```

Expected response:
```
HTTP/2 200
access-control-allow-origin: *
access-control-allow-methods: POST,OPTIONS
access-control-allow-headers: Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token
```

## Additional Fix: S3 Bucket CORS

After fixing API Gateway CORS, we also needed to configure CORS on the S3 bucket itself because the frontend uploads files directly to S3 using pre-signed URLs.

### S3 CORS Configuration

```json
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag", "x-amz-server-side-encryption", "x-amz-request-id", "x-amz-id-2"],
      "MaxAgeSeconds": 3000
    }
  ]
}
```

### Applied Using AWS CLI

```bash
aws s3api put-bucket-cors \
  --bucket niryatsaathi-documents-262343431547 \
  --cors-configuration file://s3-cors-config.json
```

### Verification

```bash
curl -X OPTIONS 'https://niryatsaathi-documents-262343431547.s3.amazonaws.com/' \
  -H 'Origin: http://localhost:3000' \
  -H 'Access-Control-Request-Method: PUT' \
  -H 'Access-Control-Request-Headers: content-type' \
  -i
```

Expected headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, PUT, POST, DELETE, HEAD
Access-Control-Allow-Headers: content-type
```

## Status
✅ **FULLY FIXED** - CORS is now working correctly for:
1. ✅ API Gateway endpoints (OPTIONS method)
2. ✅ S3 bucket (direct file uploads)

The PWA frontend can now successfully upload images and documents without any CORS errors.

## Date Fixed
March 8, 2026 (API Gateway + S3 Bucket)
