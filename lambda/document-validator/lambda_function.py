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
        s3_key = body.get('s3_key', '')
        file_id = body.get('file_id', '')
        
        if not s3_key:
            return error_response(400, "s3_key is required")
        
        # Step 1: Extract text using Textract
        print(f"Extracting text from: {s3_key}")
        extracted_data = extract_document_data(s3_key)
        
        if not extracted_data:
            return error_response(500, "Failed to extract document data")
        
        # Step 2: Validate using AI
        print("Validating extracted data...")
        validation_results = validate_with_ai(extracted_data, 'invoice')
        
        # Step 3: Format response
        return success_response({
            'file_id': file_id,
            'document_type': 'invoice',
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
    Extract text and key-value pairs from document
    For text files: read directly from S3
    For images/PDFs: would use Textract (requires subscription)
    """
    try:
        # Check file extension
        file_ext = s3_key.split('.')[-1].lower()
        
        if file_ext in ['txt', 'text']:
            # Read text file directly from S3
            print(f"Reading text file from S3: {s3_key}")
            response = s3.get_object(Bucket=S3_BUCKET, Key=s3_key)
            full_text = response['Body'].read().decode('utf-8')
            
        elif file_ext in ['pdf', 'jpg', 'jpeg', 'png']:
            # Try Textract for images/PDFs
            print(f"Attempting Textract for {file_ext} file")
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
                
                # Extract text from blocks
                blocks = response.get('Blocks', [])
                text_content = []
                for block in blocks:
                    if block['BlockType'] == 'LINE':
                        text_content.append(block['Text'])
                
                full_text = '\n'.join(text_content)
                
            except Exception as textract_error:
                print(f"Textract not available: {textract_error}")
                return {
                    'error': 'Textract requires subscription. Please use text files for testing.',
                    'note': 'For production, enable Textract in your AWS account'
                }
        else:
            return {
                'error': f'Unsupported file type: {file_ext}',
                'supported_types': 'txt (no subscription), pdf/jpg/png (requires Textract subscription)'
            }
        
        # Extract common fields using pattern matching
        extracted_data = {
            'full_text': full_text,
            'exporter_name': extract_field(full_text, ['exporter:', 'exporter name:', 'seller:']),
            'iec_number': extract_field(full_text, ['iec number:', 'iec no:', 'iec:']),
            'hsn_code': extract_field(full_text, ['hsn code:', 'hsn:', 'hs code:']),
            'invoice_number': extract_field(full_text, ['invoice number:', 'invoice no:', 'inv no:']),
            'invoice_date': extract_field(full_text, ['invoice date:', 'date:', 'inv date:']),
            'invoice_value': extract_field(full_text, ['total value:', 'total:', 'amount:', 'invoice value:']),
            'destination_country': extract_field(full_text, ['destination country:', 'destination:', 'country:', 'to country:']),
            'product_description': extract_field(full_text, ['product description:', 'description:', 'product:', 'goods:'])
        }
        
        return extracted_data
        
    except Exception as e:
        print(f"Extraction error: {e}")
        return None


def extract_field(text, keywords):
    """
    Extract field value from text based on keywords
    Improved to handle multiple keyword matches and better parsing
    """
    lines = text.split('\n')
    for i, line in enumerate(lines):
        line_lower = line.lower()
        for keyword in keywords:
            # Check if keyword is in the line
            if keyword in line_lower:
                # Try to get the value from the same line after colon
                if ':' in line:
                    parts = line.split(':', 1)  # Split only on first colon
                    value = parts[1].strip()
                    if value:  # Only return if value is not empty
                        return value
                # If no colon or empty value, try next line
                elif i + 1 < len(lines):
                    next_line = lines[i + 1].strip()
                    if next_line and not ':' in next_line:  # Avoid getting another label
                        return next_line
    return None


def validate_with_ai(extracted_data, document_type):
    """
    Validate extracted data using Bedrock AI
    """
    prompt = f"""You are an export document validation expert for India.

Document Type: {document_type}
Extracted Fields:
{json.dumps(extracted_data, indent=2)}

Validate this document and identify ONLY PROBLEMS, ERRORS, or WARNINGS.

Check for:
1. IEC number format (must be exactly 10 digits) - flag if INVALID
2. HSN code format (must be exactly 8 digits) - flag if INVALID
3. Invoice value - flag if MISSING or INVALID
4. Invoice date - flag if MISSING, INVALID, or IN FUTURE
5. Destination country - flag ONLY if field is COMPLETELY MISSING or EMPTY (ignore spelling/format)
6. Missing required fields - flag if ANY ARE MISSING
7. Inconsistencies - flag if ANY FOUND

DO NOT FLAG:
- Country name spelling (United State = valid, United States = valid)
- Country name format (any format is acceptable)
- Country name case (upper, lower, title case all acceptable)
- Country name variations (USA, US, United States all acceptable)
- Any country name that is present in any form

CRITICAL RULES:
- Only include items in "issues" array if there is an ACTUAL PROBLEM
- Do NOT include confirmations that fields are valid
- Empty "issues" array means document is valid
- ALWAYS provide "recommendations" array with helpful suggestions to improve the document

RECOMMENDATIONS (ALWAYS PROVIDE 2-3):
- Suggest adding missing optional fields (buyer address, payment terms, shipping details)
- Recommend including additional documentation (packing list, certificate of origin)
- Suggest improvements to formatting or clarity
- Provide export compliance tips
- Recommend verification steps

COUNTRY NAME VALIDATION:
- ANY country name in ANY format is COMPLETELY ACCEPTABLE and VALID
- DO NOT FLAG country names for ANY reason (spelling, format, case, etc.)
- "United States", "United State", "USA", "US", "UNITED STATES" - ALL PERFECTLY VALID
- "India", "INDIA", "India (IN)", "INDIA - IN" - ALL PERFECTLY VALID
- "United Kingdom", "UK", "Britain", "Great Britain" - ALL PERFECTLY VALID
- Title case, UPPER CASE, lower case - ALL PERFECTLY ACCEPTABLE
- With or without ISO codes - BOTH PERFECTLY ACCEPTABLE
- Minor spelling variations - PERFECTLY ACCEPTABLE (NEVER flag)
- Typos or misspellings - PERFECTLY ACCEPTABLE (NEVER flag)
- DO NOT EVER flag country name issues of any kind
- ONLY flag if country field is completely MISSING or empty
- NEVER EVER flag "United State" vs "United States" - both are perfectly acceptable
- NEVER mention country name in issues or warnings

EXAMPLES OF VALID COUNTRY NAMES (NEVER FLAG ANY OF THESE):
- "United State" ✓ PERFECTLY VALID - DO NOT FLAG
- "United States" ✓ PERFECTLY VALID
- "USA" ✓ PERFECTLY VALID
- "India" ✓ PERFECTLY VALID
- "INDIA" ✓ PERFECTLY VALID
- "UK" ✓ PERFECTLY VALID
- "United Kingdom" ✓ PERFECTLY VALID

IF COUNTRY NAME IS PRESENT IN ANY FORM: DO NOT FLAG IT, DO NOT MENTION IT, TREAT IT AS VALID.

Return validation results as JSON:
{{
  "status": "valid" | "warning" | "error",
  "issues": [
    {{
      "field": "field_name",
      "issue": "what is wrong",
      "severity": "error" | "warning"
    }}
  ],
  "recommendations": [
    "Add buyer's complete address for customs clearance",
    "Include payment terms (e.g., 30 days net)",
    "Consider adding certificate of origin"
  ]
}}

IMPORTANT: Always include 2-3 recommendations even if document is valid.
Return ONLY the JSON, no other text."""

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
