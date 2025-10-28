import boto3
import os

def lambda_handler(event, context):
    # Get Knowledge Base and Data Source IDs from environment variables
    knowledge_base_id = os.environ['KNOWLEDGE_BASE_ID']
    data_source_id = os.environ['DATA_SOURCE_ID']

    bedrock_agent_client = boto3.client('bedrock-agent', region_name=os.environ['AWS_REGION'])

    try:
        # Start the ingestion job
        response = bedrock_agent_client.start_ingestion_job(
            knowledgeBaseId=knowledge_base_id,
            dataSourceId=data_source_id
        )
        print(f"Ingestion job started successfully: {response['ingestionJob']}")
        return {
            'statusCode': 200,
            'body': 'Ingestion job started successfully.'
        }
    except Exception as e:
        print(f"Error starting ingestion job: {e}")
        raise e