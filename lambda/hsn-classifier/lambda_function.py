"""
HSNClassifier Lambda Function
Classifies products into HSN codes using Amazon Bedrock (Claude Sonnet 4.5)
"""

import boto3
import json
import uuid
import os
from datetime import datetime
from decimal import Decimal

# Initialize AWS clients
bedrock = boto3.client('bedrock-runtime', region_name='ap-south-1')
dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
translate = boto3.client('translate', region_name='ap-south-1')

# Environment variables
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'apac.anthropic.claude-3-5-sonnet-20240620-v1:0')
HSN_TABLE_NAME = os.environ.get('HSN_TABLE_NAME', 'HSNCodeMaster')
AUDIT_TABLE_NAME = os.environ.get('AUDIT_TABLE_NAME', 'AuditLog')

# DynamoDB tables
hsn_table = dynamodb.Table(HSN_TABLE_NAME)
audit_table = dynamodb.Table(AUDIT_TABLE_NAME)


def lambda_handler(event, context):
    """
    Main Lambda handler for HSN classification
    """
    try:
        # Parse request
        body = json.loads(event.get('body', '{}'))
        product_description = body.get('product_description', '').strip()
        language = body.get('language', 'en')
        user_id = body.get('user_id', 'anonymous')
        
        # Validate input
        if not product_description:
            return error_response(400, "product_description is required")
        
        # Translate to English if needed
        description_en = product_description
        if language == 'hi':
            try:
                response = translate.translate_text(
                    Text=product_description,
                    SourceLanguageCode='hi',
                    TargetLanguageCode='en'
                )
                description_en = response['TranslatedText']
            except Exception as e:
                print(f"Translation error: {e}")
                # Continue with original text if translation fails
        
        # Retrieve similar HSN codes from DynamoDB
        similar_hsn = retrieve_similar_hsn(description_en)
        
        # Build Bedrock prompt
        prompt = build_classification_prompt(description_en, similar_hsn)
        
        # Call Bedrock
        start_time = datetime.now()
        hsn_results = call_bedrock(prompt)
        processing_time = (datetime.now() - start_time).total_seconds() * 1000
        
        # Enrich with restrictions from DynamoDB
        for result in hsn_results:
            enrich_with_restrictions(result)
        
        # Translate explanations back to Hindi if needed
        if language == 'hi':
            for result in hsn_results:
                try:
                    response = translate.translate_text(
                        Text=result['explanation'],
                        SourceLanguageCode='en',
                        TargetLanguageCode='hi'
                    )
                    result['explanation'] = response['TranslatedText']
                except Exception as e:
                    print(f"Translation error for explanation: {e}")
        
        # Log to audit table
        log_to_audit(user_id, product_description, language, hsn_results, processing_time)
        
        return success_response({
            'hsn_codes': hsn_results,
            'processing_time_ms': int(processing_time)
        })
        
    except Exception as e:
        print(f"Error in lambda_handler: {e}")
        return error_response(500, f"Internal server error: {str(e)}")


def retrieve_similar_hsn(description):
    """
    Query DynamoDB for similar HSN codes based on keywords
    """
    try:
        # Extract keywords from description
        keywords = description.lower().split()[:5]  # Use first 5 words
        
        # For hackathon: scan with filter (not optimal but works)
        # In production: use GSI with keyword search
        response = hsn_table.scan(
            Limit=10,
            FilterExpression='contains(#kw, :kw1) OR contains(#kw, :kw2) OR contains(#kw, :kw3)',
            ExpressionAttributeNames={
                '#kw': 'Keywords'
            },
            ExpressionAttributeValues={
                ':kw1': keywords[0] if len(keywords) > 0 else 'product',
                ':kw2': keywords[1] if len(keywords) > 1 else 'item',
                ':kw3': keywords[2] if len(keywords) > 2 else 'goods'
            }
        )
        
        return response.get('Items', [])[:10]
        
    except Exception as e:
        print(f"Error retrieving similar HSN: {e}")
        return []


def build_classification_prompt(description, similar_hsn):
    """
    Build prompt for Bedrock with context
    """
    context = "\n".join([
        f"- HSN {hsn.get('HSNCode', 'N/A')}: {hsn.get('Description', 'N/A')}"
        for hsn in similar_hsn[:10]
    ])
    
    if not context:
        context = "No similar HSN codes found in database."
    
    return f"""You are an expert in Indian customs HSN code classification.

Product Description: {description}

Similar HSN codes from database:
{context}

Task: Classify this product into the top 3 most appropriate 8-digit HSN codes.

For each HSN code, provide:
1. The 8-digit code
2. Confidence score (0.0 to 1.0) - be realistic, most products should have 0.7-0.9 for top match
3. Brief description of what this code covers
4. Plain language explanation of why this code applies to the product

Format your response as JSON:
{{
    "classifications": [
        {{
            "code": "12345678",
            "confidence": 0.85,
            "description": "Brief description of HSN code",
            "explanation": "Why this code applies to the product"
        }}
    ]
}}

Return exactly 3 classifications, ordered by confidence (highest first)."""


def call_bedrock(prompt):
    """
    Call Amazon Bedrock and parse response
    """
    try:
        response = bedrock.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1500,
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
        
        # Extract JSON from response
        start = content.find('{')
        end = content.rfind('}') + 1
        
        if start >= 0 and end > start:
            json_str = content[start:end]
            data = json.loads(json_str)
            classifications = data.get('classifications', [])[:3]
            
            # Ensure we have 3 results
            while len(classifications) < 3:
                classifications.append({
                    'code': '00000000',
                    'confidence': 0.1,
                    'description': 'Unable to classify',
                    'explanation': 'Insufficient information for classification'
                })
            
            return classifications
        else:
            raise ValueError("No valid JSON found in Bedrock response")
            
    except Exception as e:
        print(f"Bedrock error: {e}")
        # Return default response on error
        return [
            {
                'code': '00000000',
                'confidence': 0.1,
                'description': 'Classification failed',
                'explanation': f'Error calling AI service: {str(e)}'
            }
        ]


def enrich_with_restrictions(result):
    """
    Enrich result with restriction data from DynamoDB
    """
    try:
        hsn_code = result['code']
        response = hsn_table.get_item(Key={'HSNCode': hsn_code})
        
        if 'Item' in response:
            item = response['Item']
            result['restrictions'] = item.get('ExportRestrictions', 'None')
            result['licenses_required'] = item.get('LicensesRequired', [])
        else:
            result['restrictions'] = 'None'
            result['licenses_required'] = []
        
        # Generate warning
        result['warning'] = generate_warning(result['confidence'], result['restrictions'])
        
    except Exception as e:
        print(f"Error enriching with restrictions: {e}")
        result['restrictions'] = 'Unknown'
        result['licenses_required'] = []
        result['warning'] = generate_warning(result['confidence'], 'Unknown')


def generate_warning(confidence, restrictions):
    """
    Generate warning message based on confidence and restrictions
    """
    warnings = []
    
    if confidence < 0.8:
        warnings.append("Confidence below 80% - verify with customs broker")
    
    if restrictions and restrictions not in ['None', 'Unknown']:
        warnings.append(f"Requires: {restrictions}")
    
    return " | ".join(warnings) if warnings else None


def log_to_audit(user_id, product_description, language, hsn_results, processing_time):
    """
    Log classification to audit table
    """
    try:
        # Convert float to Decimal for DynamoDB
        hsn_results_decimal = []
        for result in hsn_results:
            result_copy = result.copy()
            result_copy['confidence'] = Decimal(str(result['confidence']))
            hsn_results_decimal.append(result_copy)
        
        audit_table.put_item(Item={
            'LogID': str(uuid.uuid4()),
            'Timestamp': datetime.now().isoformat(),
            'UserID': user_id,
            'OperationType': 'HSN_Classification',
            'ProductDescription': product_description,
            'Language': language,
            'SuggestedHSN': hsn_results_decimal,
            'ProcessingTimeMs': Decimal(str(int(processing_time)))
        })
    except Exception as e:
        print(f"Error logging to audit: {e}")
        # Don't fail the request if audit logging fails


def success_response(data):
    """
    Return success response with CORS headers
    """
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
    """
    Return error response with CORS headers
    """
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
