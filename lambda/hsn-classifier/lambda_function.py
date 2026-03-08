import json
import boto3
import os

bedrock = boto3.client('bedrock-runtime', region_name='ap-south-1')

# Get model ID from environment variable
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'qwen.qwen3-235b-a22b-2507-v1:0')

def lambda_handler(event, context):
    """HSN Code Classifier using Bedrock Claude"""
    
    # Extract product description from request
    body = json.loads(event['body']) if isinstance(event.get('body'), str) else event
    product_description = body.get('product_description', '')
    
    if not product_description:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({'error': 'product_description is required'})
        }
    
    # Call Bedrock Claude
    prompt = f"""You are an HSN code classification expert for Indian exports.

Product description: {product_description}

Return the top 3 most likely 8-digit HSN codes for this product with:
1. HSN code
2. Confidence score (0-1)
3. Brief explanation

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
        
        # Parse Qwen response format
        if 'choices' in result and len(result['choices']) > 0:
            ai_response = result['choices'][0]['message']['content']
        elif 'content' in result:
            ai_response = result['content'][0]['text']
        elif 'output' in result:
            ai_response = result['output']['text']
        else:
            ai_response = str(result)
        
        # Try to parse the JSON from the response
        classifications = []
        try:
            # Extract JSON if it's embedded in the text
            if isinstance(ai_response, str):
                start = ai_response.find('{')
                end = ai_response.rfind('}') + 1
                if start >= 0 and end > start:
                    json_str = ai_response[start:end]
                    parsed_data = json.loads(json_str)
                    
                    # Handle different response formats and normalize
                    if 'classifications' in parsed_data:
                        classifications = parsed_data['classifications']
                    elif 'results' in parsed_data:
                        classifications = parsed_data['results']
                    elif 'predictions' in parsed_data:
                        classifications = parsed_data['predictions']
                    elif 'suggestions' in parsed_data:
                        classifications = parsed_data['suggestions']
                    else:
                        # Assume the parsed data itself is the array
                        classifications = parsed_data if isinstance(parsed_data, list) else [parsed_data]
            else:
                classifications = ai_response if isinstance(ai_response, list) else [ai_response]
        except Exception as parse_error:
            print(f"Parse error: {parse_error}")
            classifications = []
        
        # Normalize field names to be consistent
        normalized_classifications = []
        for item in classifications:
            normalized_item = {
                'hsn_code': item.get('hsn_code') or item.get('code'),
                'confidence': item.get('confidence') or item.get('confidence_score', 0.5),
                'explanation': item.get('explanation') or item.get('description', 'No explanation provided')
            }
            normalized_classifications.append(normalized_item)
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'product': product_description,
                'classifications': normalized_classifications,
                'model_used': BEDROCK_MODEL_ID
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({'error': str(e)})
        }
