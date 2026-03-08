"""
DocumentProcessor Lambda Function
Extracts fields from documents using Amazon Textract
"""

import boto3
import json
import os

# Initialize AWS clients
textract = boto3.client('textract', region_name='ap-south-1')
s3 = boto3.client('s3', region_name='ap-south-1')


def lambda_handler(event, context):
    """
    Main Lambda handler for document processing
    """
    try:
        # Get S3 path from event
        bucket = event.get('bucket')
        key = event.get('key')
        s3_path = event.get('s3_path', f"s3://{bucket}/{key}")
        
        if not bucket or not key:
            return {
                'statusCode': 400,
                'error': 'bucket and key are required'
            }
        
        # Call Textract
        print(f"Processing document: {bucket}/{key}")
        response = textract.analyze_document(
            Document={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            },
            FeatureTypes=['FORMS', 'TABLES']
        )
        
        # Extract key-value pairs
        extracted_fields = extract_key_value_pairs(response)
        
        # Parse specific fields for invoice
        parsed_fields = {
            'exporter_name': find_field(extracted_fields, ['exporter', 'seller', 'from', 'shipper']),
            'iec_number': find_field(extracted_fields, ['iec', 'iec number', 'iec no', 'iec code']),
            'hsn_code': find_field(extracted_fields, ['hsn', 'hsn code', 'hs code', 'hsn/sac']),
            'invoice_value': find_field(extracted_fields, ['total', 'amount', 'value', 'invoice value', 'total amount']),
            'destination_country': find_field(extracted_fields, ['country', 'destination', 'to', 'consignee country']),
            'document_date': find_field(extracted_fields, ['date', 'invoice date', 'document date'])
        }
        
        print(f"Extracted fields: {parsed_fields}")
        
        return {
            'statusCode': 200,
            'extracted_fields': parsed_fields,
            's3_path': s3_path,
            'bucket': bucket,
            'key': key
        }
        
    except Exception as e:
        print(f"Error in document processing: {e}")
        return {
            'statusCode': 500,
            'error': f"Document processing failed: {str(e)}",
            's3_path': event.get('s3_path', ''),
            'extracted_fields': {}
        }


def extract_key_value_pairs(textract_response):
    """
    Extract key-value pairs from Textract response
    """
    blocks = textract_response.get('Blocks', [])
    key_map = {}
    value_map = {}
    block_map = {}
    
    # Build block maps
    for block in blocks:
        block_id = block['Id']
        block_map[block_id] = block
        
        if block['BlockType'] == 'KEY_VALUE_SET':
            if 'KEY' in block.get('EntityTypes', []):
                key_map[block_id] = block
            else:
                value_map[block_id] = block
    
    # Extract key-value pairs
    kvs = {}
    for key_id, key_block in key_map.items():
        value_block = find_value_block(key_block, value_map)
        key_text = get_text(key_block, block_map)
        value_text = get_text(value_block, block_map) if value_block else ''
        
        if key_text and value_text:
            kvs[key_text.lower().strip()] = value_text.strip()
    
    return kvs


def find_value_block(key_block, value_map):
    """
    Find the value block associated with a key block
    """
    if 'Relationships' in key_block:
        for relationship in key_block['Relationships']:
            if relationship['Type'] == 'VALUE':
                for value_id in relationship['Ids']:
                    if value_id in value_map:
                        return value_map[value_id]
    return None


def get_text(block, block_map):
    """
    Get text from a block by traversing child relationships
    """
    if not block:
        return ''
    
    text = ''
    if 'Relationships' in block:
        for relationship in block['Relationships']:
            if relationship['Type'] == 'CHILD':
                for child_id in relationship['Ids']:
                    if child_id in block_map:
                        child = block_map[child_id]
                        if child['BlockType'] == 'WORD':
                            text += child.get('Text', '') + ' '
                        elif child['BlockType'] == 'SELECTION_ELEMENT':
                            if child.get('SelectionStatus') == 'SELECTED':
                                text += 'X '
    
    return text.strip()


def find_field(extracted_fields, possible_keys):
    """
    Find field value by checking multiple possible key names
    """
    for key in possible_keys:
        for extracted_key, value in extracted_fields.items():
            if key in extracted_key:
                return value
    return None
