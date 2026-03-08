# NiryatSaathi - Public Deployment URLs

## 🌐 Live Application

### Frontend (PWA)
**S3 Website URL:**
```
http://niryatsaathi-frontend.s3-website.ap-south-1.amazonaws.com
```

**Status:** ✅ Live and publicly accessible

### Backend API
**API Gateway URL:**
```
https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod
```

**Endpoints:**
- `POST /api/v1/classify-product` - HSN Classification
- `POST /api/v1/upload-document` - Get pre-signed upload URL
- `POST /api/v1/validate-document` - Validate document

**Status:** ✅ Live and working

---

## 📱 How to Access

### Desktop/Laptop
1. Open browser (Chrome, Firefox, Safari, Edge)
2. Go to: http://niryatsaathi-frontend.s3-website.ap-south-1.amazonaws.com
3. Use the app!

### Mobile
1. Open browser on your phone
2. Go to: http://niryatsaathi-frontend.s3-website.ap-south-1.amazonaws.com
3. Add to Home Screen for PWA experience:
   - **iOS**: Tap Share → Add to Home Screen
   - **Android**: Tap Menu → Add to Home Screen

---

## 🚀 Features Available

### 1. HSN Code Classifier
- Enter product description
- Get AI-powered HSN code suggestions
- See confidence scores and explanations
- Works in real-time

### 2. Document Validator
- Upload invoice documents (.txt files)
- Get instant field extraction
- AI-powered validation
- Error detection and recommendations

---

## 🔄 Redeployment

To update the frontend after making changes:

```bash
cd niryat-saathi
./scripts/deploy-frontend.sh
```

This will:
1. Build the React app
2. Upload to S3
3. Make it publicly accessible

---

## 💰 Hosting Costs

### Current Setup (S3 Only)
- S3 Storage: ~₹5/month (for static files)
- S3 Data Transfer: ~₹50/month (for 1000 users)
- **Total: ~₹55/month**

### With CloudFront (Optional)
- CloudFront: ~₹200/month (faster, HTTPS, global CDN)
- **Total: ~₹255/month**

---

## 🔒 Security Notes

- Frontend is served over HTTP (S3 website)
- API is served over HTTPS (API Gateway)
- For production, consider:
  - Adding CloudFront for HTTPS on frontend
  - Adding custom domain (niryatsaathi.com)
  - Adding authentication

---

## 📊 Analytics

To track usage, you can add:
- Google Analytics
- AWS CloudWatch (for API calls)
- Custom logging in Lambda functions

---

## 🎯 Next Steps

### For Better User Experience:
1. **Add HTTPS** - Set up CloudFront distribution
2. **Custom Domain** - Register niryatsaathi.com
3. **SSL Certificate** - Use AWS Certificate Manager (free)
4. **CDN** - CloudFront for faster global access

### For Production:
1. Add user authentication (Cognito)
2. Add rate limiting (API Gateway)
3. Set up monitoring (CloudWatch)
4. Add error tracking (Sentry)

---

## 📞 Share Your App

Share this URL with anyone:
```
http://niryatsaathi-frontend.s3-website.ap-south-1.amazonaws.com
```

They can:
- Use it immediately (no installation)
- Add to home screen (PWA)
- Access from any device
- Use all features for free

---

**Deployed:** March 8, 2026
**Status:** ✅ Production Ready
**Region:** ap-south-1 (Mumbai)
