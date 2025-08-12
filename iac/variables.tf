variable "region" {
  description = "The AWS region to deploy resources into."
  type        = string
}

variable "account_id" {
  description = "The AWS account ID."
  type        = string
}

variable "bucket_name" {
  description = "The name of the S3 bucket for the Bedrock knowledge base."
  type        = string
}

variable "secret_arn" {
  description = "The name of the Secrets Manager secret for the data source."
  type        = string
}

variable "pinecone_host" {
  description = "The host URL for your Pinecone index."
  type        = string
}