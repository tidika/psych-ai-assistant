# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

variable "domain_name" {
  description = "Your custom domain for the ALB."
  type        = string
  default = "psychaiassistant.mountpointe.com/oauth2/idpresponse"
}

variable "sub_domain" {
  description = "Your custom domain for the ALB."
  type        = string
  default = "psychaiassistant.mountpointe.com"
}

variable "project_name" {
  description = "A unique name for your project."
  type        = string
  default     = "psych-ai-assistant"
}

variable "certificate_arn" {
  description = "The ARN of your ACM certificate for the domain."
  type        = string
  default = "arn:aws:acm:us-east-1:930627915954:certificate/f2cc90e9-8257-4d55-95ea-aed68034054c"
}

variable "aws_region" {
  description = "AWS region code is executed on."
  type        = string
  default = "us-east-1"
}

