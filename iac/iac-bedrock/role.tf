#Creates role that AWS bedrock will assume.
resource "aws_iam_role" "bedrock_role" {
  name = "bedrock_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {
            "Service": "bedrock.amazonaws.com"
        },
        "Action": "sts:AssumeRole",
        "Condition": {
            "StringEquals": {
                "aws:SourceAccount": "${var.account_id}"
            },
            "ArnLike": {
                "AWS:SourceArn": "arn:aws:bedrock:${var.region}:${var.account_id}:knowledge-base/*"
            }
        }
    }]
}
EOF
}

#creates an iam policy that is attached to the bedrock role
resource "aws_iam_role_policy" "bedrock_policy" {
  name = "bedrock_policy"
  role = aws_iam_role.bedrock_role.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:ListFoundationModels",
                "bedrock:ListCustomModels"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "S3ListBucketStatement",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${var.bucket_name}",
                "arn:aws:s3:::${var.bucket_name}/",
                "arn:aws:s3:::${var.bucket_name}/*"
            ]
        },
        {
            "Sid": "GetSecretValue",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "${var.secret_arn}"
            ]
        }
    ]
}

EOF
}


#creates role for the lambda function that ingests new data to the knowledgebase.
# Data source to automatically zip the Python code
data "archive_file" "lambda_ingestion_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_ingest.py"
  output_path = "${path.module}/lambda_ingest_payload.zip"
}

# -----------------------------------------------------------------------------
# LAMBDA IAM ROLE AND POLICY
# -----------------------------------------------------------------------------
# IAM Role for the Lambda function
resource "aws_iam_role" "ingestion_lambda_role" {
  name = "bedrock-ingestion-lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach the AWSLambdaBasicExecutionRole managed policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.ingestion_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach the AmazonBedrockFullAccess managed policy
resource "aws_iam_role_policy_attachment" "bedrock_full_access" {
  role       = aws_iam_role.ingestion_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}


