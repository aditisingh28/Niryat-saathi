# S3 Bucket CORS Configuration Fix

## Issue
After fixing API Gateway CORS, the frontend was still getting CORS errors when trying to upload files to S3 using pre-signed URLs.

## Error Symptoms
```
Access to XMLHttpRequest at 'https://niryatsaathi-documents-262343431547.s3.amazonaws.com/...' 
from origin 'http://localhost:3000' has been blocked by CORS policy: 
Response to preflight request doesn't pass access control check
```

## Root Cause
The S3 bucket `niryatsaathi-documents-262343431547` didn't have CORS configuration. When the browser tries to upload files directly to S3 using pre-signed URLs, it sends an OPTIONS preflight request to S3, which was being rejected.

## Solution

### 1. Created CORS Configuration

```json
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": [
        "ETag",
        "x-amz-server-side-encryption",
        "x-amz-request-id",
        "x-amz-id-2"
      ],
      "MaxAgeSeconds": 3000
    }
  ]
}
```

### 2. Applied to S3 Bucket

```bash
aws s3api put-bucket-cors \
  --bucket niryatsaathi-documents-262343431547 \
  --cors-configuration file://s3-cors-config.json
```

### 3. Verified Configuration

```bash
aws s3api get-bucket-cors \
  --bucket niryatsaathi-documents-262343431547
```

## Testing

### Test S3 CORS Preflight
```bash
curl -X OPTIONS 'https://niryatsaathi-documents-262343431547.s3.amazonaws.com/' \
  -H 'Origin: http://localhost:3000' \
  -H 'Access-Control-Request-Method: PUT' \
  -H 'Access-Control-Request-Headers: content-type' \
  -i
```

### Expected Response
```
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, PUT, POST, DELETE, HEAD
Access-Control-Allow-Headers: content-type
Access-Control-Expose-Headers: ETag, x-amz-server-side-encryption, x-amz-request-id, x-amz-id-2
Access-Control-Max-Age: 3000
```

## Complete CORS Setup

For the document upload feature to work, CORS must be configured in TWO places:

### 1. API Gateway (for API endpoints)
- ✅ OPTIONS method on `/api/v1/upload-document`
- ✅ OPTIONS method on `/api/v1/validate-document`
- ✅ CORS headers in responses

### 2. S3 Bucket (for direct file uploads)
- ✅ CORS rules on `niryatsaathi-documents-262343431547`
- ✅ Allow PUT method from any origin
- ✅ Allow all headers

## Why Both Are Needed

1. **API Gateway CORS**: Required for the initial API calls to get pre-signed URLs
2. **S3 Bucket CORS**: Required for the actual file upload to S3 using the pre-signed URL

The frontend flow is:
```
Browser → API Gateway (get pre-signed URL) → Browser → S3 (upload file)
          ↑ needs CORS                                  ↑ needs CORS
```

## Status
✅ **FIXED** - Both API Gateway and S3 bucket now have proper CORS configuration.

## Verification
Run the test script:
```bash
./scripts/test-frontend-upload.sh
```

Expected output:
```
✅ CORS preflight: Working
✅ Get upload URL: Working
✅ S3 upload: Working
✅ Document validation: Working
🎉 Frontend upload flow is fully functional!
```

## Date Fixed
March 8, 2026, 5:35 PM IST

## Notes
- CORS configuration allows uploads from any origin (`*`)
- For production, consider restricting `AllowedOrigins` to your specific domain
- The configuration allows all common HTTP methods and headers
- `MaxAgeSeconds: 3000` means browsers will cache the CORS preflight for 50 minutes
