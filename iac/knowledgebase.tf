#create the knowledgebase
resource "aws_bedrockagent_knowledge_base" "chatbot" {
  name     = "psych-opioid-ai-assistant-knowledge-base"
  role_arn = "arn:aws:iam::${var.account_id}:role/bedrock_role"

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
      #embedding_model_configuration {
        #bedrock_embedding_model_configuration {
          #dimensions          = 1536
          #embedding_data_type = "FLOAT32"
        #}
      #}
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = "PINECONE"
    pinecone_configuration {
      connection_string    = "${var.pinecone_host}"
      credentials_secret_arn = "${var.secret_arn}"
      field_mapping {
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
    
  }
}

#resource for creating an s3 data source
resource "aws_bedrockagent_data_source" "s3_data_source" {
  name               = "knowledge-base-SOP-s3"
  knowledge_base_id  =  aws_bedrockagent_knowledge_base.chatbot.id
  description        = "S3 data source for SOP documents."
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = "arn:aws:s3:::psych-ai-assistant-bucket"
    }
  }
  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens      = 500
        overlap_percentage = 10 
      }
    }
  }
}