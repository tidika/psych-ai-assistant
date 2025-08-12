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


