# NiryatSaathi - AI-Powered Export Assistant 🚀

An intelligent platform helping Indian MSME exporters with HSN code classification and document validation using AWS Bedrock AI.

## 🌟 Features

### 1. HSN Code Classifier
- **AI-Powered Classification**: Get top 3 HSN code suggestions for any product
- **Confidence Scoring**: Visual confidence indicators (98%, 85%, 70%)
- **Detailed Explanations**: Understand why each HSN code applies
- **Multilingual Support**: Works in English and Hindi
- **Fast & Accurate**: Results in under 5 seconds

### 2. Beautiful UI
- **Recommendation Banner**: Highlights the best HSN code match
- **Progress Bars**: Visual confidence representation
- **Ranked Results**: Clear #1, #2, #3 ranking system
- **Mobile Responsive**: Works on all devices
- **Color-Coded**: Green (high), Yellow (medium), Red (low confidence)

## 🏗️ Architecture

- **Frontend**: React.js with modern CSS
- **Backend**: AWS Lambda (Python 3.11)
- **AI Model**: Qwen 3 (235B) via AWS Bedrock
- **API**: AWS API Gateway (REST)
- **Region**: ap-south-1 (Mumbai)

## 🚀 Live Demo

- **Frontend**: http://localhost:3000 (development)
- **API Endpoint**: https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod

## 🛠️ Setup Instructions

### Prerequisites
- Node.js 16+ and npm
- AWS Account with Bedrock access
- AWS CLI configured

### Frontend Setup
```bash
cd frontend
npm install
npm start
```

### Lambda Deployment
```bash
cd scripts
./deploy-lambda.sh
```

## 🧪 Testing

Try these example products:
- Handmade turmeric soap
- Cotton bedsheets
- Basmati rice
- Wooden toys

## 📊 API Response Format

```json
{
  "product": "handmade soap",
  "classifications": [
    {
      "hsn_code": "34011110",
      "confidence": 0.96,
      "explanation": "This code specifically covers..."
    }
  ],
  "model_used": "qwen.qwen3-235b-a22b-2507-v1:0"
}
```

## 🔧 Configuration

Update `frontend/.env`:
```
REACT_APP_API_URL=https://your-api-gateway-url.amazonaws.com/prod
```

## 📝 Project Status

- ✅ HSN Classifier with AI
- ✅ Beautiful responsive UI
- ✅ API Gateway integration
- ✅ Confidence visualization
- 🚧 Document Validator (coming soon)
- 🚧 Multilingual support (coming soon)

## 🤝 Contributing

This project was built for AI For Bharat hackathon. Contributions welcome!

## 📄 License

MIT License

## 👥 Team

Built with ❤️ for Indian MSME Exporters

---

⚠️ **Disclaimer**: This is AI-assisted decision support, not legal advice. Always verify HSN codes with customs brokers for critical export decisions.
