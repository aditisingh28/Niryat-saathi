"""
DocumentValidator Lambda Function
Validates extracted document fields using Amazon Bedrock
"""

import boto3
import json
import uuid
import re
import os
from datetime import datetime, timedelta
from decimal import Decimal

# Initialize AWS clients
bedrock = boto3.client('bedrock-runtime', region_name='ap-south-1')
dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')

# Environment variables
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'apac.anthropic.claude-3-5-sonnet-20240620-v1:0')
HISTORY_TABLE_NAME = os.environ.get('HISTORY_TABLE_NAME', 'DocumentHistory')

# DynamoDB table
history_table = dynamodb.Table(HISTORY_TABLE_NAME)


def lambda_handler(event, context):
    """
    Main Lambda handler for document validation
    """
    try:
        extracted_fields = event.get('extracted_fields', {})
        s3_path = event.get('s3_path', '')
        user_id = event.get('user_id', 'anonymous')
        
        print(f"Validating fields: {extracted_fields}")
        
        # Perform basic validation
        errors = []
        
        # Validate IEC number format (10 digits)
        iec_number = extracted_fields.get('iec_number')
        if iec_number:
            # Remove spaces and special characters
            iec_clean = re.sub(r'[^0-9]', '', iec_number)
            if not re.match(r'^\d{10}$', iec_clean):
                errors.append({
                    'type': 'definite',
                    'field': 'iec_number',
                    'message': f"Invalid IEC format: {iec_number}. IEC must be 10 digits.",
                    'fix_instruction': 'Verify your IEC number. It should be exactly 10 digits.'
                })
        else:
            errors.append({
                'type': 'definite',
                'field': 'iec_number',
                'message': 'IEC number not found in document.',
                'fix_instruction': 'Ensure your IEC number is clearly visible on the invoice.'
            })
        
        # Validate HSN code format (8 digits)
        hsn_code = extracted_fields.get('hsn_code')
        if hsn_code:
            # Remove spaces and special characters
            hsn_clean = re.sub(r'[^0-9]', '', hsn_code)
            if not re.match(r'^\d{8}$', hsn_clean):
                errors.append({
                    'type': 'possible',
                    'field': 'hsn_code',
                    'message': f"HSN code format may be incorrect: {hsn_code}",
                    'fix_instruction': 'HSN codes should be 8 digits. Verify with customs.'
                })
        else:
            errors.append({
                'type': 'definite',
                'field': 'hsn_code',
                'message': 'HSN code not found in document.',
                'fix_instruction': 'Add the HSN code to your invoice.'
            })
        
        # Validate date
        document_date = extracted_fields.get('document_date')
        if document_date:
            date_error = validate_date(document_date)
            if date_error:
                errors.append(date_error)
        else:
            errors.append({
                'type': 'definite',
                'field': 'document_date',
                'message': 'Document date not found.',
                'fix_instruction': 'Add the invoice date to your document.'
            })
        
        # Validate invoice value
        invoice_value = extracted_fields.get('invoice_value')
        if not invoice_value:
            errors.append({
                'type': 'definite',
                'field': 'invoice_value',
                'message': 'Invoice value not found.',
                'fix_instruction': 'Add the total invoice value to your document.'
            })
        
        # Validate exporter name
        if not extracted_fields.get('exporter_name'):
            errors.append({
                'type': 'definite',
                'field': 'exporter_name',
                'message': 'Exporter name not found.',
                'fix_instruction': 'Add the exporter/seller name to your invoice.'
            })
        
        # Validate destination country
        if not extracted_fields.get('destination_country'):
            errors.append({
                'type': 'possible',
                'field': 'destination_country',
                'message': 'Destination country not found.',
                'fix_instruction': 'Add the destination country to your invoice.'
            })
        
        # Use Bedrock for advanced validation
        bedrock_errors = validate_with_bedrock(extracted_fields)
        errors.extend(bedrock_errors)
        
        # Determine overall status
        if any(e['type'] == 'definite' for e in errors):
            status = 'Failed'
        elif errors:
            status = 'Warning'
        else:
            status = 'Approved'
        
        # Store in DynamoDB with 30-day TTL
        document_id = str(uuid.uuid4())
        ttl = int((datetime.now() + timedelta(days=30)).timestamp())
        
        # Convert to Decimal for DynamoDB
        errors_decimal = []
        for error in errors:
            error_copy = error.copy()
            errors_decimal.append(error_copy)
        
        history_table.put_item(Item={
            'DocumentID': document_id,
            'UserID': user_id,
            'S3Path': s3_path,
            'DocumentType': 'Commercial Invoice',
            'ExtractedData': extracted_fields,
            'ValidationErrors': errors_decimal,
            'ValidationStatus': status,
            'CreatedAt': datetime.now().isoformat(),
            'TTL': ttl
        })
        
        print(f"Validation complete: {status}, {len(errors)} errors")
        
        return {
            'statusCode': 200,
            'document_id': document_id,
            'status': status,
            'extracted_fields': extracted_fields,
            'errors': errors
        }
        
    except Exception as e:
        print(f"Error in document validation: {e}")
        return {
            'statusCode': 500,
            'error': f"Validation failed: {str(e)}",
            'document_id': None,
            'status': 'Error',
            'extracted_fields': event.get('extracted_fields', {}),
            'errors': [{
                'type': 'definite',
                'field': 'system',
                'message': f'System error: {str(e)}',
                'fix_instruction': 'Please try again or contact support.'
            }]
        }


def validate_date(date_str):
    """
    Validate document date
    """
    try:
        # Try multiple date formats
        date_formats = ['%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y', '%m/%d/%Y']
        doc_date = None
        
        for fmt in date_formats:
            try:
                doc_date = datetime.strptime(date_str, fmt)
                break
            except ValueError:
                continue
        
        if not doc_date:
            return {
                'type': 'definite',
                'field': 'document_date',
                'message': f"Invalid date format: {date_str}",
                'fix_instruction': 'Use format: YYYY-MM-DD or DD/MM/YYYY'
            }
        
        # Check if future date
        if doc_date > datetime.now():
            return {
                'type': 'definite',
                'field': 'document_date',
                'message': f"Future date detected: {date_str}",
                'fix_instruction': 'Verify the invoice date. It should not be in the future.'
            }
        
        # Check if too old
        if doc_date < datetime.now() - timedelta(days=90):
            return {
                'type': 'possible',
                'field': 'document_date',
                'message': f"Invoice is more than 90 days old: {date_str}",
                'fix_instruction': 'Check if this is the correct invoice date.'
            }
        
        return None
        
    except Exception as e:
        return {
            'type': 'definite',
            'field': 'document_date',
            'message': f"Error validating date: {date_str}",
            'fix_instruction': 'Ensure date is in a standard format (YYYY-MM-DD or DD/MM/YYYY)'
        }


def validate_with_bedrock(fields):
    """
    Use Bedrock to validate field consistency
    """
    try:
        prompt = f"""You are an export document validator. Review these extracted fields from a commercial invoice:

{json.dumps(fields, indent=2)}

Check for:
1. Missing required fields
2. Inconsistent or suspicious values
3. Common export document errors

Return a JSON array of errors (if any) in this format:
[
    {{
        "type": "definite" or "possible",
        "field": "field_name",
        "message": "error description",
        "fix_instruction": "how to fix"
    }}
]

If no additional errors beyond missing fields, return an empty array: []

Be concise and focus on critical issues only."""
        
        response = bedrock.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 800,
                "temperature": 0.3,
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            })
        )
        
        response_body = json.loads(response['body'].read())
        content = response_body['content'][0]['text']
        
        # Extract JSON array
        start = content.find('[')
        end = content.rfind(']') + 1
        
        if start >= 0 and end > start:
            json_str = content[start:end]
            errors = json.loads(json_str)
            return errors if isinstance(errors, list) else []
        
        return []
        
    except Exception as e:
        print(f"Bedrock validation error: {e}")
        return []
