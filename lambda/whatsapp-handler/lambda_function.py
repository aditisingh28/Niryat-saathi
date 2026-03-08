"""
WhatsApp Handler Lambda Function
Handles WhatsApp Business API webhook for NiryatSaathi
"""

import boto3
import json
import os
import requests
from datetime import datetime

# Initialize AWS clients
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
    print(f"Received event: {json.dumps(event)}")
    
    # Webhook verification (GET request)
    if event.get('httpMethod') == 'GET':
        return verify_webhook(event)
    
    # Message handling (POST request)
    if event.get('httpMethod') == 'POST':
        return handle_message(event)
    
    return {
        'statusCode': 400,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'error': 'Invalid request'})
    }


def verify_webhook(event):
    """
    Verify webhook for WhatsApp Business API
    """
    params = event.get('queryStringParameters', {})
    mode = params.get('hub.mode')
    token = params.get('hub.verify_token')
    challenge = params.get('hub.challenge')
    
    print(f"Webhook verification: mode={mode}, token={token}")
    
    if mode == 'subscribe' and token == VERIFY_TOKEN:
        print("Webhook verified successfully")
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'text/plain'},
            'body': challenge
        }
    
    print("Webhook verification failed")
    return {
        'statusCode': 403,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'error': 'Verification failed'})
    }


def handle_message(event):
    """
    Handle incoming WhatsApp messages
    """
    try:
        body = json.loads(event.get('body', '{}'))
        print(f"Message body: {json.dumps(body)}")
        
        # Extract message data
        entry = body.get('entry', [{}])[0]
        changes = entry.get('changes', [{}])[0]
        value = changes.get('value', {})
        messages = value.get('messages', [])
        
        if not messages:
            print("No messages in webhook")
            return {'statusCode': 200, 'body': 'No messages'}
        
        message = messages[0]
        from_number = message.get('from')
        message_type = message.get('type')
        message_id = message.get('id')
        
        print(f"Processing message from {from_number}, type: {message_type}")
        
        # Get conversation state
        state = get_conversation_state(from_number)
        print(f"Current state for {from_number}: {state}")
        
        # Handle different message types
        if message_type == 'text':
            text = message.get('text', {}).get('body', '').strip()
            print(f"Text message: {text}")
            response = handle_text_message(from_number, text, state)
        elif message_type == 'image':
            print("Image message received")
            response = handle_image_message(from_number, message, state)
        elif message_type == 'document':
            print("Document message received")
            response = handle_document_message(from_number, message, state)
        else:
            response = "Sorry, I can only process text messages and documents. 📝"
        
        # Send response
        print(f"Sending response: {response[:100]}...")
        send_result = send_whatsapp_message(from_number, response)
        print(f"Send result: {send_result}")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'success': True, 'message_id': message_id})
        }
        
    except Exception as e:
        print(f"Error handling message: {e}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }


def handle_text_message(from_number, text, state):
    """
    Handle text messages based on conversation state
    """
    text_lower = text.lower().strip()
    
    # Commands
    if text_lower in ['/start', 'hi', 'hello', 'start', 'menu', 'namaste']:
        update_conversation_state(from_number, 'menu')
        return get_main_menu()
    
    if text_lower in ['/help', 'help']:
        return get_help_message()
    
    if text_lower in ['/reset', 'reset']:
        update_conversation_state(from_number, 'menu')
        return "Conversation reset! ✅\n\n" + get_main_menu()
    
    # Menu selection
    if state == 'menu' or state is None:
        if text in ['1', 'hsn', 'classify', 'classification']:
            update_conversation_state(from_number, 'hsn_classify')
            return ("Great! 🔍\n\n"
                   "Please describe your product.\n\n"
                   "*Examples:*\n"
                   "• handmade turmeric soap\n"
                   "• cotton bedsheets\n"
                   "• basmati rice\n"
                   "• wooden toys")
        elif text in ['2', 'document', 'validate', 'validation']:
            update_conversation_state(from_number, 'document_validate')
            return ("Perfect! 📄\n\n"
                   "Please send me your invoice document.\n\n"
                   "*Supported formats:*\n"
                   "• PDF\n"
                   "• JPG/JPEG\n"
                   "• PNG\n"
                   "• TXT\n\n"
                   "Max size: 10MB")
        elif text in ['3', 'help']:
            return get_help_message()
        else:
            return ("Please select an option:\n\n"
                   "1️⃣ HSN Classification\n"
                   "2️⃣ Document Validation\n"
                   "3️⃣ Help\n\n"
                   "Reply with 1, 2, or 3")
    
    # HSN Classification state
    if state == 'hsn_classify':
        return classify_product(text)
    
    # Document validation state (waiting for document)
    if state == 'document_validate':
        return ("Please send your document as an image or PDF.\n\n"
               "Or type /start to go back to the main menu.")
    
    # Default - show menu
    update_conversation_state(from_number, 'menu')
    return get_main_menu()


def classify_product(product_description):
    """
    Classify product using HSNClassifier Lambda
    """
    try:
        print(f"Classifying product: {product_description}")
        
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
        
        print(f"Got {len(classifications)} classifications")
        
        if not classifications:
            return ("Sorry, I couldn't find HSN codes for that product. 😕\n\n"
                   "Please try describing it differently or be more specific.\n\n"
                   "Type another product name or /start for menu.")
        
        # Format response for WhatsApp
        message = f"🔍 *HSN Codes for \"{product_description}\"*\n\n"
        
        for i, cls in enumerate(classifications[:3], 1):
            confidence = cls.get('confidence', 0) * 100
            emoji = "✅" if confidence >= 80 else "⚠️"
            
            message += f"*{i}️⃣ HSN: {cls.get('hsn_code')}*\n"
            message += f"Confidence: {confidence:.0f}% {emoji}\n"
            message += f"_{cls.get('explanation', '')}_\n\n"
        
        message += "💡 *Important:* Always verify with customs broker\n\n"
        message += "Need another classification? Just type the product name!\n"
        message += "Or type /start for main menu."
        
        return message
        
    except Exception as e:
        print(f"Error classifying product: {e}")
        import traceback
        traceback.print_exc()
        return ("Sorry, there was an error processing your request. 😕\n\n"
               "Please try again or type /start for main menu.")


def handle_image_message(from_number, message, state):
    """
    Handle image messages (for document validation)
    """
    if state != 'document_validate':
        return ("Please select option 2 (Document Validation) first.\n\n"
               "Type /start to see the main menu.")
    
    # For now, return a message that document validation is coming soon
    # In production, you would:
    # 1. Download image from WhatsApp using media ID
    # 2. Upload to S3
    # 3. Call DocumentValidator Lambda
    # 4. Format and return results
    
    return ("📄 *Document received!*\n\n"
           "Document validation via WhatsApp is coming soon! 🚀\n\n"
           "For now, please use our web app:\n"
           "https://niryatsaathi.in\n\n"
           "Type /start for main menu.")


def handle_document_message(from_number, message, state):
    """
    Handle document messages (PDFs)
    """
    if state != 'document_validate':
        return ("Please select option 2 (Document Validation) first.\n\n"
               "Type /start to see the main menu.")
    
    return ("📄 *Document received!*\n\n"
           "Document validation via WhatsApp is coming soon! 🚀\n\n"
           "For now, please use our web app:\n"
           "https://niryatsaathi.in\n\n"
           "Type /start for main menu.")


def get_main_menu():
    """
    Get main menu message
    """
    return ("*Welcome to NiryatSaathi!* 🇮🇳\n\n"
           "I can help you with:\n\n"
           "1️⃣ *HSN Code Classification*\n"
           "   Get instant HSN codes for your products\n\n"
           "2️⃣ *Document Validation*\n"
           "   Validate export documents\n\n"
           "3️⃣ *Help*\n"
           "   Learn how to use this service\n\n"
           "Reply with *1*, *2*, or *3*")


def get_help_message():
    """
    Get help message
    """
    return ("*NiryatSaathi Help* 📚\n\n"
           "*Commands:*\n"
           "/start - Show main menu\n"
           "/help - Show this help\n"
           "/reset - Start over\n\n"
           "*Features:*\n"
           "1️⃣ *HSN Classification*\n"
           "   Get HSN codes for your products\n\n"
           "2️⃣ *Document Validation*\n"
           "   Validate export documents\n\n"
           "*Tips:*\n"
           "• Be specific when describing products\n"
           "• Use clear, readable documents\n"
           "• Always verify HSN codes with customs\n\n"
           "Need more help?\n"
           "Visit: https://niryatsaathi.in")


def get_conversation_state(phone_number):
    """
    Get conversation state from DynamoDB
    """
    try:
        response = conversations_table.get_item(
            Key={'phone_number': phone_number}
        )
        item = response.get('Item', {})
        return item.get('state', 'menu')
    except Exception as e:
        print(f"Error getting state: {e}")
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
        print(f"Updated state for {phone_number} to {state}")
    except Exception as e:
        print(f"Error updating state: {e}")


def send_whatsapp_message(to_number, message):
    """
    Send message via WhatsApp Business API
    """
    if not WHATSAPP_TOKEN or not WHATSAPP_PHONE_ID:
        print("WhatsApp credentials not configured")
        return {'error': 'WhatsApp not configured'}
    
    url = f"https://graph.facebook.com/v18.0/{WHATSAPP_PHONE_ID}/messages"
    
    headers = {
        'Authorization': f'Bearer {WHATSAPP_TOKEN}',
        'Content-Type': 'application/json'
    }
    
    data = {
        'messaging_product': 'whatsapp',
        'to': to_number,
        'type': 'text',
        'text': {
            'preview_url': False,
            'body': message
        }
    }
    
    try:
        response = requests.post(url, headers=headers, json=data, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error sending WhatsApp message: {e}")
        return {'error': str(e)}
