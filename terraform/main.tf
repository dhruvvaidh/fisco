terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      //version = "~> 4.66.0"  # or any 4.x version
      version = ">= 5.0"
    }
  }
  backend "s3" {
    bucket         = "dhruv-fisco"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}


resource "aws_iam_role" "amplify_role" {
  name = "amplify-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_policy_attachment" "amplify_full_access" {
  name       = "amplify-full-access"
  roles      = [aws_iam_role.amplify_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}

# Amplify App
resource "aws_amplify_app" "plaid_app" {
  name         = "FiscAI"
  repository   = "https://github.com/leo111223/fisco.git"
  oauth_token  = var.github_token
  platform     = "WEB"
  iam_service_role_arn = aws_iam_role.amplify_role.arn
  enable_branch_auto_deletion = true

  environment_variables = {
    REACT_APP_ENV        = "production"
    REACT_APP_PLAID_ENV  = var.plaid_environment
    # VITE_API_BASE_URL   = var.api_url       ##
  }

  auto_branch_creation_config {
    enable_auto_build          = true
    enable_pull_request_preview = false
    framework = "React"
    stage     = "PRODUCTION"
  }

  build_spec = <<EOT
version: 1
applications:
  - appRoot: fisc-ai/frontend
    frontend:
      phases:
        preBuild:
          commands:
            - npm install
            - npm install vite --save-dev --legacy-peer-deps
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: build
        files:
          - "**/*"
      cache:
        paths:
          - node_modules/**/*
  - appRoot: fisc-ai/backend/python
    backend:
      phases:
        preBuild:
          commands:
            - pip install -r requirements.txt
        build:
          commands:
            - python server.py
      artifacts:
        baseDirectory: .
        files:
          - "**/*"
      cache:
        paths:
          - .venv/**/*
EOT


}

# Amplify Main Branch
resource "aws_amplify_branch" "main_branch" {
  app_id      = aws_amplify_app.plaid_app.id
  branch_name = var.branch_name
  stage       = "PRODUCTION"
  enable_auto_build = true

  environment_variables = {
    REACT_APP_ENV       = "production"
    REACT_APP_PLAID_ENV = var.plaid_environment
    # VITE_API_BASE_URL   = var.api_url
  }
}

resource "aws_dynamodb_table" "transactions" {
  name         = "Transactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "transaction_id"

  attribute {
    name = "transaction_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  global_secondary_index {
    name               = "user_id-index"
    hash_key           = "user_id"
    projection_type    = "ALL"
  }
}

# DynamoDB Table for Accounts
resource "aws_dynamodb_table" "accounts" {
  name         = "Accounts"  # Name of the accounts table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "account_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "account_id"
    type = "S"
  }
}


# S3 bucket policy
resource "aws_s3_bucket" "receipt_bucket" {
  bucket        = "receipt-${var.aws_account_id}" 
  #bucket        = "receipt-1112233" 
  force_destroy = true
}

resource "aws_s3_bucket_cors_configuration" "receipt_bucket_cors" {
  bucket = aws_s3_bucket.receipt_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "allow_textract_access" {
  bucket = aws_s3_bucket.receipt_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowTextractToAccessS3"
        Effect    = "Allow"
        Principal = {
          Service = "textract.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.receipt_bucket.arn}/*"
      }
    ]
  })
}
