# terraform.tfvars

aws_region = "us-east-1"

repo_url = "https://github.com/dhruvvaidh/fisco"

app_name = "FiscAI"
#branch_name = "amplify_branch"
branch_name = "main"


# plaid_client_id  = "67ad2ec20245ff0021df5364"
# plaid_secret     = "b87f4cfceb87f20dbdf89dc2602c2a"

plaid_client_id  = "679dd136d378b10023942d78"
plaid_secret     = "959c6a0ea2fd1deb626d707ca00d4f"
plaid_environment = "sandbox"

# lambda_function_name = "transaction_handler"
# dynamodb_table_name  = "transactions"

environment = "test-fiscai"

# lex_role_arn = aws_iam_role.lex_service_role.arn

# PLAID_CLIENT_ID = "679dd136d378b10023942d78"  # Replace with your actual client ID
# PLAID_SECRET = "959c6a0ea2fd1deb626d707ca00d4f"        # Replace with your actual secret

aws_account_id = 971422697727