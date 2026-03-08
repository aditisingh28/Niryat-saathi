"""
Document Upload Lambda Function
Generates pre-signed S3 URLs for document upload and triggers validation
"""

import boto3
import json
import os
import uuid
from datetime import datetime

# Initialize AWS clients
s3 = boto3.client('s3', region_name='ap-south-1')
lambda_client = boto3.client('lambda', region_name='ap-south-1')

# Environment variables
S3_BUCKET = os.environ.get('S3_BUCKET', 'niryatsaathi-documents')
VALIDATOR_FUNCTION = os.environ.get('VALIDATOR_FUNCTION', 'DocumentValidator')

def lambda_handler(event, context):
    """
    Generate pre-signed URL for document upload
    """
    try:
        # Parse request
        body = json.loads(event.get('body', '{}'))
        file_name = body.get('file_name', 'document.pdf')
        file_type = body.get('file_type', 'application/pdf')
        
        # Generate unique file key
        file_id = str(uuid.uuid4())
        file_extension = file_name.split('.')[-1] if '.' in file_name else 'pdf'
        s3_key = f"documents/{datetime.now().strftime('%Y/%m/%d')}/{file_id}.{file_extension}"
        
        # Generate pre-signed URL for upload (valid for 5 minutes)
        presigned_url = s3.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': S3_BUCKET,
                'Key': s3_key,
                'ContentType': file_type
            },
            ExpiresIn=300
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'upload_url': presigned_url,
                's3_key': s3_key,
                'file_id': file_id,
                'message': 'Upload your file to the provided URL using PUT request'
            })
        }
        
    except Exception as e:
        print(f"Error: {e}")
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


def trigger_validation(s3_key, file_id):
    """
    Trigger document validation Lambda function
    """
    try:
        payload = {
            'body': json.dumps({
                's3_key': s3_key,
                'file_id': file_id
            })
        }
        
        response = lambda_client.invoke(
            FunctionName=VALIDATOR_FUNCTION,
            InvocationType='Event',  # Async invocation
            Payload=json.dumps(payload)
        )
        
        return True
    except Exception as e:
        print(f"Error triggering validation: {e}")
        return False
