# NiryatSaathi Frontend

React-based frontend for the NiryatSaathi export compliance assistant.

## Setup

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Configure API URL**
   ```bash
   cp .env.example .env
   # Edit .env and add your API Gateway URL
   ```

3. **Run development server**
   ```bash
   npm start
   ```
   
   Opens at http://localhost:3000

4. **Build for production**
   ```bash
   npm run build
   ```
   
   Creates optimized build in `build/` directory

## Deployment to S3/CloudFront

After building:

```bash
# Create S3 bucket for frontend
aws s3 mb s3://niryatsaathi-frontend-${ACCOUNT_ID} --region ap-south-1

# Enable static website hosting
aws s3 website s3://niryatsaathi-frontend-${ACCOUNT_ID} \
  --index-document index.html \
  --error-document index.html

# Upload build files
aws s3 sync build/ s3://niryatsaathi-frontend-${ACCOUNT_ID}/ --delete

# Create CloudFront distribution (see deployment guide)
```

## Features

- **HSN Classifier**: AI-powered product classification
- **Document Validator**: Automated invoice validation
- **Multilingual**: English and Hindi support
- **Mobile-responsive**: Works on all devices

## Environment Variables

- `REACT_APP_API_URL`: API Gateway endpoint URL

## Tech Stack

- React 18
- React Router 6
- Axios
- CSS3 (no framework for minimal size)
