variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "app_name" {
  description = "Amplify App Name"
}

variable "repo_url" {
  description = "GitHub Repository URL"
}

variable "github_token" {
  description = "GitHub OAuth Token"
  type = string
  sensitive   = true
}

variable "branch_name" {
  description = "Git Branch Name"
  default     = "main"
}

variable "plaid_client_id" {
  description = "Plaid API Client ID"
  sensitive   = true
}

variable "plaid_secret" {
  description = "Plaid API Secret Key"
  sensitive   = true
}

variable "plaid_environment" {
  description = "Plaid Environment (sandbox, development, production)"
  default     = "sandbox"
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
  default     = "transaction_handler"
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "transactions"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, test, prod)"
  type        = string
  default     = "test"
}

variable "aws_account_id" {
  description = "The AWS account ID"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
}

# variable "lex_role_arn" {
#   description = "IAM Role ARN used by Lex"
#   type        = string
# }

# variable "lex_bot_name" {
#   description = "The name of the Lex bot"
#   type        = string
# }

# variable "lex_bot_alias" {
#   description = "The alias of the Lex bot"
#   type        = string
# }

