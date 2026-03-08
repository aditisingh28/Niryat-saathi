"""
Document Validator Lambda Function
Validates export documents using Amazon Textract and Bedrock AI
"""

import boto3
import json
import os
from datetime import datetime

# Initialize AWS clients
textract = boto3.client('textract', region_name='ap-south-1')
bedrock = boto3.client('bedrock-runtime', region_name='ap-south-1')
s3 = boto3.client('s3', region_name='ap-south-1')

# Environment variables
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'qwen.qwen3-235b-a22b-2507-v1:0')
S3_BUCKET = os.environ.get('S3_BUCKET', 'niryatsaathi-documents')

def lambda_handler(event, context):
    """
    Main Lambda handler for document validation
    """
    try:
        # Parse request
        body = json.loads(event.get('body', '{}'))
        document_url = body.get('document_url', '')
        document_type = body.get('document_type', 'invoice')
        
        if not document_url:
            return error_response(400, "document_url is required")
        
        # Extract S3 key from URL
        s3_key = extract_s3_key(document_url)
        
        # Step 1: Extract text using Textract
        print(f"Extracting text from: {s3_key}")
        extracted_data = extract_document_data(s3_key)
        
        if not extracted_data:
            return error_response(500, "Failed to extract document data")
        
        # Step 2: Validate using AI
        print("Validating extracted data...")
        validation_results = validate_with_ai(extracted_data, document_type)
        
        # Step 3: Format response
        return success_response({
            'document_type': document_type,
            'extracted_fields': extracted_data,
            'validation_results': validation_results,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        print(f"Error in lambda_handler: {e}")
        return error_response(500, f"Internal server error: {str(e)}")


def extract_s3_key(url):
    """Extract S3 key from URL"""
    # Handle both S3 URLs and pre-signed URLs
    if 's3.amazonaws.com' in url or 's3-' in url:
        parts = url.split('/')
        # Find the bucket name and get everything after it
        for i, part in enumerate(parts):
            if S3_BUCKET in part:
                return '/'.join(parts[i+1:]).split('?')[0]
    return url


def extract_document_data(s3_key):
    """
    Extract text and key-value pairs from document using Textract
    """
    try:
        response = textract.analyze_document(
            Document={
                'S3Object': {
                    'Bucket': S3_BUCKET,
                    'Name': s3_key
                }
            },
            FeatureTypes=['FORMS', 'TABLES']
        )
        
        # Extract key-value pairs
        extracted_data = {}
        blocks = response.get('Blocks', [])
        
        # Simple extraction - look for common fields
        text_content = []
        for block in blocks:
            if block['BlockType'] == 'LINE':
                text_content.append(block['Text'])
        
        full_text = '\n'.join(text_content)
        
        # Extract common fields using pattern matching
        extracted_data = {
            'full_text': full_text,
            'exporter_name': extract_field(full_text, ['exporter', 'seller', 'from']),
            'iec_number': extract_field(full_text, ['iec', 'iec no', 'iec number']),
            'hsn_code': extract_field(full_text, ['hsn', 'hsn code', 'hs code']),
            'invoice_number': extract_field(full_text, ['invoice', 'invoice no', 'invoice number']),
            'invoice_date': extract_field(full_text, ['date', 'invoice date']),
            'invoice_value': extract_field(full_text, ['value', 'amount', 'total']),
            'destination_country': extract_field(full_text, ['destination', 'country', 'to']),
            'product_description': extract_field(full_text, ['description', 'product', 'goods'])
        }
        
        return extracted_data
        
    except Exception as e:
        print(f"Textract error: {e}")
        return None


def extract_field(text, keywords):
    """
    Extract field value from text based on keywords
    """
    lines = text.split('\n')
    for i, line in enumerate(lines):
        line_lower = line.lower()
        for keyword in keywords:
            if keyword in line_lower:
                # Try to get the value from the same line or next line
                parts = line.split(':')
                if len(parts) > 1:
                    return parts[1].strip()
                elif i + 1 < len(lines):
                    return lines[i + 1].strip()
    return None


def validate_with_ai(extracted_data, document_type):
    """
    Validate extracted data using Bedrock AI
    """
    prompt = f"""You are an export document validation expert for India.

Document Type: {document_type}
Extracted Fields:
{json.dumps(extracted_data, indent=2)}

Validate this document and identify any errors or warnings:
1. Check if IEC number format is valid (10 digits)
2. Check if HSN code format is valid (8 digits)
3. Check if invoice value is present and valid
4. Check if date is valid and not in future
5. Check if destination country is specified
6. Check for any missing required fields
7. Check for any inconsistencies

Return validation results as JSON with:
- status: "valid", "warning", or "error"
- issues: array of issues found
- recommendations: array of recommendations

Format as JSON."""

    try:
        response = bedrock.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=json.dumps({
                'messages': [{
                    'role': 'user',
                    'content': prompt
                }],
                'max_tokens': 1000
            })
        )
        
        result = json.loads(response['body'].read())
        
        # Parse response
        if 'choices' in result and len(result['choices']) > 0:
            ai_response = result['choices'][0]['message']['content']
        else:
            ai_response = str(result)
        
        # Extract JSON from response
        try:
            if isinstance(ai_response, str):
                start = ai_response.find('{')
                end = ai_response.rfind('}') + 1
                if start >= 0 and end > start:
                    json_str = ai_response[start:end]
                    validation_data = json.loads(json_str)
                    return validation_data
        except:
            pass
        
        # Fallback validation
        return {
            'status': 'warning',
            'issues': ['Unable to fully validate document'],
            'recommendations': ['Please review document manually']
        }
        
    except Exception as e:
        print(f"Bedrock validation error: {e}")
        return {
            'status': 'error',
            'issues': [f'Validation failed: {str(e)}'],
            'recommendations': ['Please try again or contact support']
        }


def success_response(data):
    """Return success response with CORS headers"""
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'POST, OPTIONS'
        },
        'body': json.dumps(data)
    }


def error_response(status_code, message):
    """Return error response with CORS headers"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'POST, OPTIONS'
        },
        'body': json.dumps({'error': message})
    }
