# WhatsApp Integration Implementation Plan

## Overview
Enable users to interact with NiryatSaathi through WhatsApp for HSN classification and document validation.

## Architecture

```
WhatsApp User
    ↓
WhatsApp Business API
    ↓
Webhook (API Gateway)
    ↓
WhatsAppHandler Lambda
    ↓
    ├─→ HSNClassifier Lambda (for product queries)
    ├─→ DocumentValidator Lambda (for document uploads)
    └─→ DynamoDB (conversation state)
    ↓
Response back to WhatsApp
```

## Implementation Steps

### Phase 1: WhatsApp Business API Setup
1. Create Meta Business Account
2. Set up WhatsApp Business API
3. Get Phone Number ID and Access Token
4. Configure Webhook URL

### Phase 2: Lambda Function
1. Create WhatsAppHandler Lambda
2. Implement webhook verification
3. Handle incoming messages
4. Route to appropriate service
5. Format responses for WhatsApp

### Phase 3: Conversation Management
1. Store conversation state in DynamoDB
2. Handle multi-turn conversations
3. Implement menu system
4. Handle errors gracefully

### Phase 4: Testing & Deployment
1. Test with WhatsApp test number
2. Deploy to production
3. Monitor and optimize

## Features to Implement

### 1. HSN Classification via WhatsApp
**User Flow:**
```
User: Hi
Bot: Welcome to NiryatSaathi! 🇮🇳
     I can help you with:
     1️⃣ HSN Code Classification
     2️⃣ Document Validation
     
     Reply with 1 or 2

User: 1
Bot: Great! Please describe your product.
     Example: "handmade turmeric soap"

User: cotton bedsheets
Bot: 🔍 Searching HSN codes...

Bot: Here are the top HSN codes for "cotton bedsheets":

     1️⃣ HSN: 63022100
     Confidence: 95% ✅
     Description: Bed linen of cotton
     
     2️⃣ HSN: 63021010
     Confidence: 85% ⚠️
     Description: Bed sheets, cotton, bleached
     
     3️⃣ HSN: 63021090
     Confidence: 70% ⚠️
     Description: Other cotton bed linen
     
     💡 Tip: Verify with customs broker for final confirmation
     
     Need help with another product? Just type it!
```

### 2. Document Validation via WhatsApp
**User Flow:**
```
User: 2
Bot: Please send me your invoice document.
     Supported formats: PDF, JPG, PNG
     Max size: 10MB

User: [sends image]
Bot: 📄 Processing your document...

Bot: ✅ Document Validation Results:
     
     Status: Valid
     
     📋 Extracted Fields:
     • Exporter: ABC Exports
     • IEC: 0123456789
     • HSN: 34011110
     • Value: USD 5,000
     • Destination: USA
     
     ✅ No errors found!
     
     💡 Recommendations:
     • Include buyer's address
     • Add payment terms
     
     Need to validate another document? Send it!
```

### 3. Menu System
```
Main Menu:
1️⃣ HSN Code Classification
2️⃣ Document Validation
3️⃣ Help
4️⃣ About

Commands:
/start - Show main menu
/help - Get help
/reset - Start over
```

## Technical Implementation

### 1. WhatsApp Business API Setup

**Requirements:**
- Meta Business Account
- WhatsApp Business API access
- Phone number for WhatsApp Business

**Steps:**
1. Go to https://business.facebook.com
2. Create Business Account
3. Add WhatsApp product
4. Get test phone number
5. Generate access token
6. Configure webhook

### 2. Lambda Function: WhatsAppHandler

**File**: `lambda/whatsapp-handler/lambda_function.py`

```python
import boto3
import json
import os
import requests
from datetime import datetime

# Initialize clients
dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
lambda_client = boto3.client('lambda', region_name='ap-south-1')

# Environment variables
WHATSAPP_TOKEN = os.environ.get('WHATSAPP_TOKEN')
WHATSAPP_PHONE_ID = os.environ.get('WHATSAPP_PHONE_ID')
VERIFY_TOKEN = os.environ.get('VERIFY_TOKEN', 'niryatsaathi_verify_token')
CONVERSATION_TABLE = os.environ.get('CONVERSATION_TABLE', 'WhatsAppConversations')

conversations_table = dynamodb.Table(CONVERSATION_TABLE)

def lambda_handler(event, context):
    """
    Handle WhatsApp webhook events
    """
    # Webhook verification (GET request)
    if event.get('httpMethod') == 'GET':
        return verify_webhook(event)
    
    # Message handling (POST request)
    if event.get('httpMethod') == 'POST':
        return handle_message(event)
    
    return {
        'statusCode': 400,
        'body': json.dumps({'error': 'Invalid request'})
    }

def verify_webhook(event):
    """
    Verify webhook for WhatsApp
    """
    params = event.get('queryStringParameters', {})
    mode = params.get('hub.mode')
    token = params.get('hub.verify_token')
    challenge = params.get('hub.challenge')
    
    if mode == 'subscribe' and token == VERIFY_TOKEN:
        return {
            'statusCode': 200,
            'body': challenge
        }
    
    return {
        'statusCode': 403,
        'body': json.dumps({'error': 'Verification failed'})
    }

def handle_message(event):
    """
    Handle incoming WhatsApp messages
    """
    try:
        body = json.loads(event.get('body', '{}'))
        
        # Extract message data
        entry = body.get('entry', [{}])[0]
        changes = entry.get('changes', [{}])[0]
        value = changes.get('value', {})
        messages = value.get('messages', [])
        
        if not messages:
            return {'statusCode': 200, 'body': 'No messages'}
        
        message = messages[0]
        from_number = message.get('from')
        message_type = message.get('type')
        
        # Get conversation state
        state = get_conversation_state(from_number)
        
        # Handle different message types
        if message_type == 'text':
            text = message.get('text', {}).get('body', '').strip()
            response = handle_text_message(from_number, text, state)
        elif message_type == 'image':
            response = handle_image_message(from_number, message, state)
        elif message_type == 'document':
            response = handle_document_message(from_number, message, state)
        else:
            response = "Sorry, I can only process text messages and documents."
        
        # Send response
        send_whatsapp_message(from_number, response)
        
        return {
            'statusCode': 200,
            'body': json.dumps({'success': True})
        }
        
    except Exception as e:
        print(f"Error handling message: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def handle_text_message(from_number, text, state):
    """
    Handle text messages
    """
    text_lower = text.lower()
    
    # Commands
    if text_lower in ['/start', 'hi', 'hello', 'start', 'menu']:
        update_conversation_state(from_number, 'menu')
        return get_main_menu()
    
    if text_lower == '/help':
        return get_help_message()
    
    if text_lower == '/reset':
        update_conversation_state(from_number, 'menu')
        return "Conversation reset. " + get_main_menu()
    
    # Menu selection
    if state == 'menu':
        if text in ['1', 'hsn', 'classify']:
            update_conversation_state(from_number, 'hsn_classify')
            return "Great! 🔍\n\nPlease describe your product.\n\nExample: \"handmade turmeric soap\" or \"cotton bedsheets\""
        elif text in ['2', 'document', 'validate']:
            update_conversation_state(from_number, 'document_validate')
            return "Perfect! 📄\n\nPlease send me your invoice document.\n\nSupported: PDF, JPG, PNG\nMax size: 10MB"
        elif text in ['3', 'help']:
            return get_help_message()
        else:
            return "Please select an option:\n1️⃣ HSN Classification\n2️⃣ Document Validation\n3️⃣ Help"
    
    # HSN Classification
    if state == 'hsn_classify':
        return classify_product(text)
    
    # Default
    return get_main_menu()

def classify_product(product_description):
    """
    Classify product using HSNClassifier Lambda
    """
    try:
        # Call HSNClassifier Lambda
        response = lambda_client.invoke(
            FunctionName='HSNClassifier',
            InvocationType='RequestResponse',
            Payload=json.dumps({
                'body': json.dumps({
                    'product_description': product_description,
                    'language': 'en'
                })
            })
        )
        
        result = json.loads(response['Payload'].read())
        body = json.loads(result.get('body', '{}'))
        classifications = body.get('classifications', [])
        
        if not classifications:
            return "Sorry, I couldn't find HSN codes for that product. Please try describing it differently."
        
        # Format response for WhatsApp
        message = f"🔍 HSN Codes for \"{product_description}\":\n\n"
        
        for i, cls in enumerate(classifications[:3], 1):
            confidence = cls.get('confidence', 0) * 100
            emoji = "✅" if confidence >= 80 else "⚠️"
            
            message += f"{i}️⃣ *HSN: {cls.get('hsn_code')}*\n"
            message += f"   Confidence: {confidence:.0f}% {emoji}\n"
            message += f"   {cls.get('explanation', '')}\n\n"
        
        message += "💡 *Tip:* Verify with customs broker\n\n"
        message += "Need another classification? Just type the product name!"
        
        return message
        
    except Exception as e:
        print(f"Error classifying product: {e}")
        return "Sorry, there was an error processing your request. Please try again."

def handle_image_message(from_number, message, state):
    """
    Handle image messages (for document validation)
    """
    if state != 'document_validate':
        return "Please select option 2 (Document Validation) first to upload documents."
    
    # Download image from WhatsApp
    image_id = message.get('image', {}).get('id')
    
    # TODO: Download image, upload to S3, validate
    return "📄 Processing your document...\n\n(Document validation coming soon!)"

def handle_document_message(from_number, message, state):
    """
    Handle document messages (PDFs)
    """
    if state != 'document_validate':
        return "Please select option 2 (Document Validation) first to upload documents."
    
    # Download document from WhatsApp
    doc_id = message.get('document', {}).get('id')
    
    # TODO: Download document, upload to S3, validate
    return "📄 Processing your document...\n\n(Document validation coming soon!)"

def get_main_menu():
    """
    Get main menu message
    """
    return """Welcome to NiryatSaathi! 🇮🇳

I can help you with:

1️⃣ HSN Code Classification
2️⃣ Document Validation
3️⃣ Help

Reply with 1, 2, or 3"""

def get_help_message():
    """
    Get help message
    """
    return """*NiryatSaathi Help* 📚

*Commands:*
/start - Show main menu
/help - Show this help
/reset - Start over

*Features:*
1️⃣ HSN Classification - Get HSN codes for your products
2️⃣ Document Validation - Validate export documents

*Tips:*
• Be specific when describing products
• Use clear, readable documents
• Verify HSN codes with customs

Need more help? Visit: niryatsaathi.in"""

def get_conversation_state(phone_number):
    """
    Get conversation state from DynamoDB
    """
    try:
        response = conversations_table.get_item(
            Key={'phone_number': phone_number}
        )
        return response.get('Item', {}).get('state', 'menu')
    except:
        return 'menu'

def update_conversation_state(phone_number, state):
    """
    Update conversation state in DynamoDB
    """
    try:
        conversations_table.put_item(
            Item={
                'phone_number': phone_number,
                'state': state,
                'updated_at': datetime.now().isoformat()
            }
        )
    except Exception as e:
        print(f"Error updating state: {e}")

def send_whatsapp_message(to_number, message):
    """
    Send message via WhatsApp Business API
    """
    url = f"https://graph.facebook.com/v18.0/{WHATSAPP_PHONE_ID}/messages"
    
    headers = {
        'Authorization': f'Bearer {WHATSAPP_TOKEN}',
        'Content-Type': 'application/json'
    }
    
    data = {
        'messaging_product': 'whatsapp',
        'to': to_number,
        'type': 'text',
        'text': {'body': message}
    }
    
    try:
        response = requests.post(url, headers=headers, json=data)
        return response.json()
    except Exception as e:
        print(f"Error sending message: {e}")
        return None
```

### 3. DynamoDB Table for Conversations

```json
{
  "TableName": "WhatsAppConversations",
  "KeySchema": [
    {"AttributeName": "phone_number", "KeyType": "HASH"}
  ],
  "AttributeDefinitions": [
    {"AttributeName": "phone_number", "AttributeType": "S"}
  ],
  "BillingMode": "PAY_PER_REQUEST"
}
```

### 4. API Gateway Webhook Endpoint

- **Endpoint**: POST /api/v1/whatsapp/webhook
- **Integration**: WhatsAppHandler Lambda
- **CORS**: Not needed (WhatsApp calls directly)

## Setup Instructions

### Step 1: Meta Business Setup
1. Go to https://business.facebook.com
2. Create/select Business Account
3. Add WhatsApp product
4. Get test phone number
5. Generate permanent access token

### Step 2: Create DynamoDB Table
```bash
aws dynamodb create-table \
  --table-name WhatsAppConversations \
  --attribute-definitions AttributeName=phone_number,AttributeType=S \
  --key-schema AttributeName=phone_number,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

### Step 3: Create Lambda Function
```bash
cd lambda/whatsapp-handler
pip install requests -t .
zip -r function.zip .
aws lambda create-function \
  --function-name WhatsAppHandler \
  --runtime python3.11 \
  --role arn:aws:iam::ACCOUNT_ID:role/NiryatSaathi-Lambda-Role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip \
  --timeout 30 \
  --memory-size 256 \
  --environment Variables="{
    WHATSAPP_TOKEN=YOUR_TOKEN,
    WHATSAPP_PHONE_ID=YOUR_PHONE_ID,
    VERIFY_TOKEN=niryatsaathi_verify_token,
    CONVERSATION_TABLE=WhatsAppConversations
  }" \
  --region ap-south-1
```

### Step 4: Create API Gateway Endpoint
```bash
# Create resource
aws apigateway create-resource \
  --rest-api-id 33m1wci2fb \
  --parent-id ROOT_ID \
  --path-part whatsapp \
  --region ap-south-1

# Create webhook resource
aws apigateway create-resource \
  --rest-api-id 33m1wci2fb \
  --parent-id WHATSAPP_RESOURCE_ID \
  --path-part webhook \
  --region ap-south-1

# Add POST method
aws apigateway put-method \
  --rest-api-id 33m1wci2fb \
  --resource-id WEBHOOK_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --region ap-south-1

# Add GET method (for verification)
aws apigateway put-method \
  --rest-api-id 33m1wci2fb \
  --resource-id WEBHOOK_RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE \
  --region ap-south-1
```

### Step 5: Configure WhatsApp Webhook
1. Go to WhatsApp Business API settings
2. Set webhook URL: `https://33m1wci2fb.execute-api.ap-south-1.amazonaws.com/prod/api/v1/whatsapp/webhook`
3. Set verify token: `niryatsaathi_verify_token`
4. Subscribe to messages

### Step 6: Test
1. Send "Hi" to your WhatsApp Business number
2. Should receive welcome menu
3. Test HSN classification
4. Test document validation

## Cost Estimate

- WhatsApp Business API: Free for first 1,000 conversations/month
- Lambda executions: ~₹100/month
- DynamoDB: ~₹200/month
- **Total**: ~₹300/month (plus ₹2/conversation after 1,000)

## Timeline

- Setup (Meta + AWS): 2-3 hours
- Lambda development: 4-6 hours
- Testing: 2-3 hours
- **Total**: 1-2 days

## Next Steps

1. Create Meta Business Account
2. Get WhatsApp Business API access
3. Implement Lambda function
4. Deploy and test
5. Go live!
