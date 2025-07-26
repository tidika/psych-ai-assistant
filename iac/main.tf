
#resource for managing an AWS OpenSearch Serverless Security Policy
resource "aws_opensearchserverless_security_policy" "bedrock_encryption_policy" {
  name        = "psych-ai-assistant-encryp-policy"
  type        = "encryption"
  description = "encryption security policy for bedrock_encryption_policy"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/psych-ai-assistant-vector-store"
        ],
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}


#resource for managing an AWS OpenSearch Serverless Security Policy
resource "aws_opensearchserverless_security_policy" "bedrock_network_policy" {
  name        = "bedrock-network-policy"
  type        = "network"
  description = "Allow public access for Bedrock"
  policy      = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection",
          Resource     = [
            "collection/psych-ai-assistant-vector-store"
          ]
        },
      
        {
          ResourceType = "dashboard",
          Resource     = [
            "collection/psych-ai-assistant-vector-store"
          ]
        }
      ],
      AllowFromPublic = true
    }
  ])
}


#resource for managing bedrock vector store collection
resource "aws_opensearchserverless_collection" "bedrock_vector_store" {
  name = "psych-ai-assistant-vector-store"
  type = "VECTORSEARCH" # Crucial for vector database capabilities
  tags = {
    Project = "PsychAIAssistant"
    ManagedBy = "Terraform"
  }

  # Explicitly depend on the encryption policy
  depends_on = [
  aws_opensearchserverless_security_policy.bedrock_encryption_policy,
  aws_opensearchserverless_security_policy.bedrock_network_policy
  ]
  }

output "opensearch_endpoint" {
  value = aws_opensearchserverless_collection.bedrock_vector_store.collection_endpoint
}


#resource for creating the index
#resource for creating the index
resource "null_resource" "create_opensearch_index" {
  depends_on = [
    aws_opensearchserverless_collection.bedrock_vector_store,
  ]

  provisioner "local-exec" {
    command = "powershell -Command \"awscurl -v --service aoss --region ${data.aws_region.current.id} --request PUT --header 'Content-Type: application/json' --data @index_mapping.json 'https://${aws_opensearchserverless_collection.bedrock_vector_store.collection_endpoint}/bedrock-knowledge-base-default-index' 2>&1 | Out-File -FilePath awscurl_output.log -Append\""
  }
}


# resource for creating access policy for the bedrock knowledgebase
# Get AWS account info
# resource for creating access policy for the bedrock knowledgebase
# Get AWS account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_opensearchserverless_access_policy" "bedrock_kb_policy" {
  name        = "bedrock-kb-access"
  type        = "data"
  description = "read and write permissions" # You can adjust this description if the new permissions change its meaning
  policy      = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection", 
          Resource     = [
            "collection/${aws_opensearchserverless_collection.bedrock_vector_store.name}" 
          ],
          Permission = [
            "aoss:DescribeCollectionItems",
            "aoss:CreateCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DeleteCollectionItems"
          ]
        },
        {
          ResourceType = "index", 
          Resource     = [
            "index/${aws_opensearchserverless_collection.bedrock_vector_store.name}/*" 
          ],
          Permission = [
            "aoss:UpdateIndex",
            "aoss:DeleteIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:CreateIndex"
          ]
        }
      ],
      Principal = [
        data.aws_caller_identity.current.arn,
        aws_iam_role.bedrock_knowledge_base_role.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/bedrock.amazonaws.com/AWSServiceRoleForAmazonBedrock",
        "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/OrganizationAccountAccessRole/admin@mlopsinthecloud"
      ]
    }
  ])
}
  

#resource that creates an Bedrock IAM role with the access policy assigned to it. 
# IAM Role for Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_knowledge_base_role" {
  name = "BedrockKnowledgeBaseRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "TrustPolicyStatement",
        Effect = "Allow",
        Principal = {
          Service = "bedrock.amazonaws.com"
        },
        Action = "sts:AssumeRole",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "930627915954"
          },
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:us-east-1:930627915954:knowledge-base/*"
          }
        }
      }
    ]
  })
}

# Output the ARN of the OpenSearch Serverless Collection
output "opensearch_serverless_collection_arn" {
  description = "The ARN of the OpenSearch Serverless collection used by the Bedrock Knowledge Base."
  value       = aws_opensearchserverless_collection.bedrock_vector_store.arn
}

#bedrock policy for invoking the embedding model
resource "aws_iam_policy" "bedrock_invoke_model_policy" {
  name = "BedrockInvokeModelPolicy"
  description = "Allow Bedrock to invoke the Titan Embed Text v2 model"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "BedrockInvokeModelStatement",
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel"
        ],
        Resource = [
          "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_bedrock_invoke_model" {
  role       = aws_iam_role.bedrock_knowledge_base_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_model_policy.arn
}


# Policy for OpenSearch Serverless access
resource "aws_iam_policy" "opensearch_serverless_api_access_all" {
  name = "OpenSearchServerlessAPIAccessAll"
  description = "Allow APIAccessAll on specific OpenSearch Serverless collections"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "OpenSearchServerlessAPIAccessAllStatement",
        Effect = "Allow",
        Action = [
          "aoss:APIAccessAll"
        ],
        Resource = [
          "arn:aws:aoss:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:collection/${aws_opensearchserverless_collection.bedrock_vector_store.id}",
          "arn:aws:aoss:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:index/${aws_opensearchserverless_collection.bedrock_vector_store.id}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_opensearch_access" {
  role       = aws_iam_role.bedrock_knowledge_base_role.name
  policy_arn = aws_iam_policy.opensearch_serverless_api_access_all.arn
}

resource "aws_iam_policy" "bedrock_kb_s3_policy" {
  name = "BedrockKBS3Access"
  description = "Allow Bedrock KB role to access S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "S3ListBucketStatement",
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::psych-ai-assistant-bucket"
        ],
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = [
              "930627915954"
            ]
          }
        }
      },
      {
        Sid    = "S3GetObjectStatement",
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "arn:aws:s3:::psych-ai-assistant-bucket/*"
        ],
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = [
              "930627915954"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_bedrock_kb_s3_policy" {
  role       = aws_iam_role.bedrock_knowledge_base_role.name
  policy_arn = aws_iam_policy.bedrock_kb_s3_policy.arn
}


#resource for creating the knowledgebase
resource "aws_bedrockagent_knowledge_base" "main" {
  name        = "psych-ai-assistant-knowledge-base"
  description = "Knowledge Base for internal SOPs and guidelines."
  role_arn    = aws_iam_role.bedrock_knowledge_base_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions         = 1024
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.bedrock_vector_store.arn
      vector_index_name = "bedrock-knowledge-base-default-index"
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }
}


#Output the ARN of the Bedrock Knowledge Base IAM Role
output "bedrock_knowledge_base_role_arn" {
  description = "The ARN of the IAM role used by the Bedrock Knowledge Base."
  value       = aws_iam_role.bedrock_knowledge_base_role.arn
}


data "aws_s3_bucket" "psych_ai_assistant_bucket_data" {
  bucket = "psych-ai-assistant-bucket" 
}

resource "aws_s3_bucket_cors_configuration" "bedrock_kb_s3_cors" {
  bucket = data.aws_s3_bucket.psych_ai_assistant_bucket_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["Access-Control-Allow-Origin"]
  }
}

#resource for creating an s3 data source
resource "aws_bedrockagent_data_source" "s3_data_source" {
  name               = "knowledge-base-SOP-s3"
  knowledge_base_id  =  aws_bedrockagent_knowledge_base.main.id
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






