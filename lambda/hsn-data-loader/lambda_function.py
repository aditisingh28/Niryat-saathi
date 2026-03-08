"""
HSNDataLoader Lambda Function
Loads CBIC HSN code master data into DynamoDB
"""

import boto3
import json
import csv
import os
from io import StringIO

# Initialize AWS clients
s3 = boto3.client('s3', region_name='ap-south-1')
dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')

# Environment variables
HSN_TABLE_NAME = os.environ.get('HSN_TABLE_NAME', 'HSNCodeMaster')
S3_BUCKET = os.environ.get('S3_BUCKET', 'niryatsaathi-documents')
S3_KEY = os.environ.get('S3_KEY', 'hsn-data/hsn_master.csv')

# DynamoDB table
hsn_table = dynamodb.Table(HSN_TABLE_NAME)


def lambda_handler(event, context):
    """
    Main Lambda handler for HSN data loading
    """
    try:
        # Get S3 bucket and key from event or use defaults
        bucket = event.get('bucket', S3_BUCKET)
        key = event.get('key', S3_KEY)
        
        print(f"Loading HSN data from s3://{bucket}/{key}")
        
        # Download CSV from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        csv_content = response['Body'].read().decode('utf-8')
        
        # Parse CSV
        csv_reader = csv.DictReader(StringIO(csv_content))
        
        # Batch write to DynamoDB
        loaded_count = 0
        batch_items = []
        
        for row in csv_reader:
            # Extract HSN code and description
            hsn_code = row.get('HSN Code', '').strip()
            description = row.get('Description', '').strip()
            chapter = hsn_code[:2] if len(hsn_code) >= 2 else '00'
            heading = hsn_code[:4] if len(hsn_code) >= 4 else '0000'
            
            if not hsn_code or len(hsn_code) != 8:
                continue
            
            # Generate keywords for search
            keywords = generate_keywords(description)
            
            # Create item
            item = {
                'HSNCode': hsn_code,
                'Description': description,
                'Chapter': chapter,
                'Heading': heading,
                'Keywords': keywords,
                'ExportRestrictions': row.get('Export Restrictions', 'None'),
                'LicensesRequired': [],
                'ApplicableDuty': row.get('Duty', '0%'),
                'LastUpdated': '2025-03-08T00:00:00Z'
            }
            
            batch_items.append(item)
            
            # Batch write every 25 items
            if len(batch_items) >= 25:
                write_batch(batch_items)
                loaded_count += len(batch_items)
                batch_items = []
                print(f"Loaded {loaded_count} HSN codes...")
        
        # Write remaining items
        if batch_items:
            write_batch(batch_items)
            loaded_count += len(batch_items)
        
        print(f"Successfully loaded {loaded_count} HSN codes")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully loaded {loaded_count} HSN codes',
                'loaded_count': loaded_count
            })
        }
        
    except Exception as e:
        print(f"Error loading HSN data: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Failed to load HSN data: {str(e)}'
            })
        }


def generate_keywords(description):
    """
    Generate searchable keywords from description
    """
    # Convert to lowercase and split
    words = description.lower().split()
    
    # Remove common words
    stop_words = {'of', 'the', 'and', 'or', 'in', 'for', 'with', 'other', 'not', 'a', 'an'}
    keywords = [w for w in words if w not in stop_words and len(w) > 2]
    
    # Return unique keywords
    return list(set(keywords))[:20]  # Limit to 20 keywords


def write_batch(items):
    """
    Write batch of items to DynamoDB
    """
    try:
        with hsn_table.batch_writer() as batch:
            for item in items:
                batch.put_item(Item=item)
    except Exception as e:
        print(f"Error writing batch: {e}")
        raise
