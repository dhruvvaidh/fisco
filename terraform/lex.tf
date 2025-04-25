#lex calling lambda use this
resource "aws_iam_role" "lex_service_role" {
  name = "LexServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lex.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lex_policy" {
  name = "LexLambdaInvokePolicy"
  role = aws_iam_role.lex_service_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["lambda:InvokeFunction"],
      Resource = aws_lambda_function.query_lex_handler.arn
    }]
  })
}

# give lambda permission to call lex
resource "aws_iam_policy" "lambda_lex_policy" {
  name = "LambdaLexPolicy-leo"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lex:RecognizeText"
        ],
        Resource = "arn:aws:lex:us-east-1:${data.aws_caller_identity.current.account_id}:bot-alias/${aws_lexv2models_bot.finance_assistant.id}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_lex_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_lex_policy.arn
}

###lex lambda role
resource "aws_iam_role" "query_lex_lambda_role" {
  name = "query_lex_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
# Full access to Lex V2
resource "aws_iam_role_policy_attachment" "query_lex_lambda_lex_full_access" {
  role       = aws_iam_role.query_lex_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonLexFullAccess"
}

# Basic Lambda logging
resource "aws_iam_role_policy_attachment" "query_lex_lambda_logs" {
  role       = aws_iam_role.query_lex_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# lex lambda and permission
resource "aws_lambda_function" "query_lex_handler" {
  function_name = "query_lex_handler"
  filename      = "query_lex.zip"          # replace with your zip file
  handler       = "query_lex.lambda_handler"
  runtime       = "python3.9"
  //role          = aws_iam_role.lambda_exec.arn
  role          = aws_iam_role.query_lex_lambda_role.arn

  timeout       = 30
 environment {
  variables = {
    LEX_BOT_ID       = aws_lexv2models_bot.finance_assistant.id
    LEX_BOT_ALIAS_ID = data.external.lex_alias_id.result.lex_bot_alias_id
    #OPENAI_API_KEY = var.openai_api_key
  }
  }

  depends_on = [
    null_resource.create_lex_alias,
    aws_iam_role_policy_attachment.query_lex_lambda_logs,
    aws_iam_role_policy_attachment.query_lex_lambda_lex_full_access
  ]
}


resource "aws_lambda_permission" "allow_apigw_invoke_lambda" {
  statement_id  = "AllowAPIGatewayInvoke--leo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_lex_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.finance_api.id}/prod/POST/query_lex"
    
  depends_on = [
    aws_lambda_function.query_lex_handler,
    aws_api_gateway_deployment.api_deployment,
    aws_api_gateway_stage.api_stage
  ]
}

resource "aws_lambda_permission" "allow_apigw_invoke_query_lex" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_lex_handler.function_name
  principal     = "apigateway.amazonaws.com"

  # Adjust the REST API resource name as needed
  source_arn = "arn:aws:execute-api:us-east-1:${var.aws_account_id}:${aws_api_gateway_rest_api.finance_api.id}/*/POST/query_lex"

  depends_on = [ 
    aws_lambda_function.query_lex_handler,
    aws_api_gateway_deployment.api_deployment,
    aws_api_gateway_stage.api_stage
  ]
}

resource "aws_lambda_permission" "allow_lex_to_invoke_query_handler" {
  statement_id  = "AllowLexToInvokeQueryHandler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_lex_handler.function_name
  principal     = "lexv2.amazonaws.com"
  
  # The source ARN will be constructed from your bot ID and alias ID
  source_arn    = "arn:aws:lex:us-east-1:864981748263:bot-alias/${aws_lexv2models_bot.finance_assistant.id}/*"
}



data "aws_caller_identity" "current" {}

resource "aws_lexv2models_bot" "finance_assistant" {
  name                     = "financeAssistant"
  role_arn                 = aws_iam_role.lex_service_role.arn
  data_privacy {
    child_directed = false
  }
  idle_session_ttl_in_seconds = 300
  description                 = "Lex V2 bot for finance tracking"
}

resource "aws_lexv2models_bot_locale" "english_locale" {
  bot_id      = aws_lexv2models_bot.finance_assistant.id
  locale_id   = "en_US"
  description = "English (US) locale for Finance Assistant"
  n_lu_intent_confidence_threshold = 0.4
  bot_version                      = "DRAFT"

  voice_settings {
    voice_id = "Joanna"
  }


  depends_on = [aws_lexv2models_bot.finance_assistant]
}

# resource "null_resource" "create_lex_alias" {
#   triggers = {
#     bot_id = aws_lexv2models_bot.finance_assistant.id
#   }

#   provisioner "local-exec" {
#     when    = create
#     command = <<EOT
#       set -xe

#       # ✅First, verify the slot priority is set correctly
#       echo "Verifying slot priorities are properly set..."
#       TRANSACTIONS_INTENT_ID=$(aws lexv2-models list-intents \
#         --bot-id ${self.triggers.bot_id} \
#         --bot-version DRAFT \
#         --locale-id en_US \
#         --query "intentSummaries[?intentName=='GetRecentTransactions'].intentId" \
#         --output text)
        
#       if [[ ! -z "$TRANSACTIONS_INTENT_ID" ]]; then
#         INTENT_INFO=$(aws lexv2-models describe-intent \
#           --bot-id ${self.triggers.bot_id} \
#           --bot-version DRAFT \
#           --locale-id en_US \
#           --intent-id $TRANSACTIONS_INTENT_ID)
          
#         # Check if slotPriorities exists
#         if ! echo "$INTENT_INFO" | jq -e '.slotPriorities' > /dev/null; then
#           echo "⚠️ No slot priorities found for GetRecentTransactions intent. Setting them now..."
          
#           # Get slots for this intent
#           SLOT_ID=$(aws lexv2-models list-slots \
#             --bot-id ${self.triggers.bot_id} \
#             --bot-version DRAFT \
#             --locale-id en_US \
#             --intent-id $TRANSACTIONS_INTENT_ID \
#             --query "slotSummaries[?slotName=='NumberOfTransactions'].slotId" \
#             --output text)
            
#           if [[ ! -z "$SLOT_ID" ]]; then
#             # Create a temporary file with the intent configuration
#             echo "$INTENT_INFO" | jq 'del(.creationDateTime, .lastUpdatedDateTime, .version)' > temp_intent.json
            
#             # Add slot priority
#             jq --arg slot_id "$SLOT_ID" '.slotPriorities = [{"priority": 1, "slotId": $slot_id}]' temp_intent.json > updated_intent.json
            
#             # Update the intent
#             aws lexv2-models update-intent \
#               --bot-id ${self.triggers.bot_id} \
#               --bot-version DRAFT \
#               --locale-id en_US \
#               --intent-id $TRANSACTIONS_INTENT_ID \
#               --cli-input-json file://updated_intent.json
              
#             echo "✅ Slot priorities updated for GetRecentTransactions intent"
#           else
#             echo "⚠️ No NumberOfTransactions slot found!"
#           fi
#         else
#           echo "✅ Slot priorities already set for GetRecentTransactions intent"
#         fi
#       else
#         echo "⚠️ GetRecentTransactions intent not found!"
#       fi


#       # Step 1: Build the DRAFT locale (if not already built)
#       aws lexv2-models build-bot-locale \
#         --bot-id ${self.triggers.bot_id} \
#         --bot-version DRAFT \
#         --locale-id en_US

#       # Wait for build to complete
#       echo "🕒 Waiting for locale build to finish..."
#       for i in {1..60}; do
#         STATUS=$(aws lexv2-models describe-bot-locale \
#           --bot-id ${self.triggers.bot_id} \
#           --bot-version DRAFT \
#           --locale-id en_US \
#           --query 'botLocaleStatus' \
#           --output text)

#         echo "⏳ Current locale status: $STATUS"

#         if [[ -z "$STATUS" ]]; then
#           echo "⚠️  Failed to fetch locale status. Exiting."
#           exit 1
#         fi

#         if [[ "$STATUS" == "Built" ]]; then
#           echo "✅ Locale build complete."
#           break
#         elif [[ "$STATUS" == "Failed" ]]; then
#           echo "❌ Locale build failed. Fetching failure reasons..."
#           aws lexv2-models describe-bot-locale \
#             --bot-id ${self.triggers.bot_id} \
#             --bot-version DRAFT \
#             --locale-id en_US \
#             --query 'failureReasons' \
#             --output text
#           exit 1
#         fi

#         sleep 5
#       done


#       # Step 2: Create a version from the DRAFT
#       VERSION=$(aws lexv2-models create-bot-version \
#         --bot-id ${self.triggers.bot_id} \
#         --bot-version-locale-specification '{"en_US":{"sourceBotVersion":"DRAFT"}}' \
#         --query 'botVersion' \
#         --output text)

#       echo "✅ Published Lex bot version: $VERSION"

#       sleep 10

#       # Step 3: Create or update alias and enable locale
#       aws lexv2-models create-bot-alias \
#         --bot-id ${self.triggers.bot_id} \
#         --bot-alias-name "financeAssistantAlias" \
#         --bot-version "$VERSION" \
#         --bot-alias-locale-settings '{"en_US":{"enabled":true}}' || \
#       aws lexv2-models update-bot-alias \
#         --bot-id ${self.triggers.bot_id} \
#         --bot-alias-id $(aws lexv2-models list-bot-aliases \
#           --bot-id ${self.triggers.bot_id} \
#           --query "botAliasSummaries[?botAliasName=='financeAssistantAlias'].botAliasId" \
#           --output text) \
#         --bot-alias-name "financeAssistantAlias" \
#         --bot-version "$VERSION" \
#         --bot-alias-locale-settings '{"en_US":{"enabled":true}}'

#       echo "✅ Lex alias created and locale enabled."

#       INTENT_ID=$(aws lexv2-models list-intents \
#         --bot-id ${self.triggers.bot_id} \
#         --bot-version DRAFT \
#         --locale-id en_US \
#         --query "intentSummaries[?intentName=='greeting_intent'].intentId" \
#         --output text)

#       if [[ ! -z "$INTENT_ID" ]]; then
#       # Get the intent config
#         aws lexv2-models describe-intent \
#           --bot-id ${self.triggers.bot_id} \
#           --bot-version DRAFT \
#           --locale-id en_US \
#           --intent-id $INTENT_ID > tmp_intent.json

#       # Inject fulfillment hook
#       jq '.fulfillmentCodeHook = {"enabled": true}' tmp_intent.json > updated_intent.json

#       # Apply update
#       aws lexv2-models update-intent \
#         --bot-id ${self.triggers.bot_id} \
#         --bot-version DRAFT \
#         --locale-id en_US \
#         --intent-id $INTENT_ID \
#         --cli-input-json file://updated_intent.json


#       # Step 4: Output alias ID for use in Lambda
#       ALIAS_ID=$(aws lexv2-models list-bot-aliases \
#         --bot-id ${self.triggers.bot_id} \
#         --query "botAliasSummaries[?botAliasName=='financeAssistantAlias'].botAliasId" \
#         --output text)
#       echo "ALIAS_ID resolved: $ALIAS_ID"
#       echo "{\"lex_bot_alias_id\": \"$ALIAS_ID\"}" > lex_alias.json

#     EOT
#     interpreter = ["bash", "-c"]
#   }

#   depends_on = [
#     aws_lexv2models_bot_locale.english_locale,
#     aws_lexv2models_slot_type.transaction_count_type,
#     aws_lexv2models_slot.number_of_transactions,
#     aws_lexv2models_intent.greeting_intent,
#     aws_lexv2models_intent.get_recent_transactions,
#     aws_lexv2models_intent.goodbye_intent,
#     null_resource.update_intent_slot_priority 
#   ]
# }

resource "null_resource" "create_lex_alias" {
  triggers = {
    bot_id = aws_lexv2models_bot.finance_assistant.id
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOT
      set -xe

      # First, verify the slot priority is set correctly
      echo "Verifying slot priorities are properly set..."
      TRANSACTIONS_INTENT_ID=$(aws lexv2-models list-intents \
        --bot-id ${self.triggers.bot_id} \
        --bot-version DRAFT \
        --locale-id en_US \
        --query "intentSummaries[?intentName=='GetRecentTransactions'].intentId" \
        --output text)
        
      if [[ ! -z "$TRANSACTIONS_INTENT_ID" ]]; then
        INTENT_INFO=$(aws lexv2-models describe-intent \
          --bot-id ${self.triggers.bot_id} \
          --bot-version DRAFT \
          --locale-id en_US \
          --intent-id $TRANSACTIONS_INTENT_ID)
          
        # Check if slotPriorities exists
        if ! echo "$INTENT_INFO" | jq -e '.slotPriorities' > /dev/null; then
          echo "⚠️ No slot priorities found for GetRecentTransactions intent. Setting them now..."
          
          # Get slots for this intent
          SLOT_ID=$(aws lexv2-models list-slots \
            --bot-id ${self.triggers.bot_id} \
            --bot-version DRAFT \
            --locale-id en_US \
            --intent-id $TRANSACTIONS_INTENT_ID \
            --query "slotSummaries[?slotName=='NumberOfTransactions'].slotId" \
            --output text)
            
          if [[ ! -z "$SLOT_ID" ]]; then
            # Create a temporary file with the intent configuration
            echo "$INTENT_INFO" | jq 'del(.creationDateTime, .lastUpdatedDateTime, .version)' > temp_intent.json
            
            # Add slot priority
            jq --arg slot_id "$SLOT_ID" '.slotPriorities = [{"priority": 1, "slotId": $slot_id}]' temp_intent.json > updated_intent.json
            
            # Update the intent
            aws lexv2-models update-intent \
              --bot-id ${self.triggers.bot_id} \
              --bot-version DRAFT \
              --locale-id en_US \
              --intent-id $TRANSACTIONS_INTENT_ID \
              --cli-input-json file://updated_intent.json
              
            echo "✅ Slot priorities updated for GetRecentTransactions intent"
          else
            echo "⚠️ No NumberOfTransactions slot found!"
          fi
        else
          echo "✅ Slot priorities already set for GetRecentTransactions intent"
        fi
      else
        echo "⚠️ GetRecentTransactions intent not found!"
      fi


      # Step 1: Build the DRAFT locale (if not already built)
      aws lexv2-models build-bot-locale \
        --bot-id ${self.triggers.bot_id} \
        --bot-version DRAFT \
        --locale-id en_US

      # Wait for build to complete
      echo "🕒 Waiting for locale build to finish..."
      for i in {1..60}; do
        STATUS=$(aws lexv2-models describe-bot-locale \
          --bot-id ${self.triggers.bot_id} \
          --bot-version DRAFT \
          --locale-id en_US \
          --query 'botLocaleStatus' \
          --output text)

        echo "⏳ Current locale status: $STATUS"

        if [[ -z "$STATUS" ]]; then
          echo "⚠️  Failed to fetch locale status. Exiting."
          exit 1
        fi

        if [[ "$STATUS" == "Built" ]]; then
          echo "✅ Locale build complete."
          break
        elif [[ "$STATUS" == "Failed" ]]; then
          echo "❌ Locale build failed. Fetching failure reasons..."
          aws lexv2-models describe-bot-locale \
            --bot-id ${self.triggers.bot_id} \
            --bot-version DRAFT \
            --locale-id en_US \
            --query 'failureReasons' \
            --output text
          exit 1
        fi

        sleep 5
      done


      # Step 2: Create a version from the DRAFT
      VERSION=$(aws lexv2-models create-bot-version \
        --bot-id ${self.triggers.bot_id} \
        --bot-version-locale-specification '{"en_US":{"sourceBotVersion":"DRAFT"}}' \
        --query 'botVersion' \
        --output text)

      echo "✅ Published Lex bot version: $VERSION"

      sleep 10

      # Step 3: Create or update alias and enable locale
      aws lexv2-models create-bot-alias \
        --bot-id ${self.triggers.bot_id} \
        --bot-alias-name "financeAssistantAlias" \
        --bot-version "$VERSION" \
        --bot-alias-locale-settings '{"en_US":{"enabled":true}}' || \
      aws lexv2-models update-bot-alias \
        --bot-id ${self.triggers.bot_id} \
        --bot-alias-id $(aws lexv2-models list-bot-aliases \
          --bot-id ${self.triggers.bot_id} \
          --query "botAliasSummaries[?botAliasName=='financeAssistantAlias'].botAliasId" \
          --output text) \
        --bot-alias-name "financeAssistantAlias" \
        --bot-version "$VERSION" \
        --bot-alias-locale-settings '{"en_US":{"enabled":true}}'

      echo "✅ Lex alias created and locale enabled."

      INTENT_ID=$(aws lexv2-models list-intents \
        --bot-id ${self.triggers.bot_id} \
        --bot-version DRAFT \
        --locale-id en_US \
        --query "intentSummaries[?intentName=='greeting_intent'].intentId" \
        --output text)

      if [[ ! -z "$INTENT_ID" ]]; then
        # Get the intent config
        aws lexv2-models describe-intent \
          --bot-id ${self.triggers.bot_id} \
          --bot-version DRAFT \
          --locale-id en_US \
          --intent-id $INTENT_ID > tmp_intent.json

        # Inject fulfillment hook
        jq '.fulfillmentCodeHook = {"enabled": true}' tmp_intent.json > updated_intent.json

        # Apply update
        aws lexv2-models update-intent \
          --bot-id ${self.triggers.bot_id} \
          --bot-version DRAFT \
          --locale-id en_US \
          --intent-id $INTENT_ID \
          --cli-input-json file://updated_intent.json
      else
        echo "greeting_intent not found, skipping intent update."
      fi

      # Step 4: Output alias ID for use in Lambda
      ALIAS_ID=$(aws lexv2-models list-bot-aliases \
        --bot-id ${self.triggers.bot_id} \
        --query "botAliasSummaries[?botAliasName=='financeAssistantAlias'].botAliasId" \
        --output text)
      echo "ALIAS_ID resolved: $ALIAS_ID"
      echo "{\"lex_bot_alias_id\": \"$ALIAS_ID\"}" > lex_alias.json
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    aws_lexv2models_bot_locale.english_locale,
    aws_lexv2models_slot_type.transaction_count_type,
    aws_lexv2models_slot.number_of_transactions,
    aws_lexv2models_intent.greeting_intent,
    aws_lexv2models_intent.get_recent_transactions,
    aws_lexv2models_intent.goodbye_intent,
    null_resource.update_intent_slot_priority,
    #second intent
    aws_lexv2models_slot_type.spending_category_type,
    aws_lexv2models_slot_type.time_frame_type,
    aws_lexv2models_slot.category_slot,
    aws_lexv2models_slot.time_frame_slot,
    aws_lexv2models_intent.query_spending_by_category,
    null_resource.update_query_spending_by_category_slot_priorities
  ]
}

resource "null_resource" "attach_lambda_hook" {
  triggers = {
    bot_id     = aws_lexv2models_bot.finance_assistant.id
    lambda_arn = aws_lambda_function.query_lex_handler.arn
  }

  provisioner "local-exec" {
    command = <<EOT
      set -ex

      ALIAS_ID=$(aws lexv2-models list-bot-aliases \
        --bot-id ${self.triggers.bot_id} \
        --query "botAliasSummaries[?botAliasName=='financeAssistantAlias'].botAliasId" \
        --output text)

      VERSION=$(aws lexv2-models list-bot-aliases \
        --bot-id ${self.triggers.bot_id} \
        --query "botAliasSummaries[?botAliasName=='financeAssistantAlias'].botVersion" \
        --output text)

      aws lexv2-models update-bot-alias \
        --bot-id ${self.triggers.bot_id} \
        --bot-alias-id "$ALIAS_ID" \
        --bot-alias-name "financeAssistantAlias" \
        --bot-version "$VERSION" \
        --bot-alias-locale-settings '{
          "en_US": {
            "enabled": true,
            "codeHookSpecification": {
              "lambdaCodeHook": {
                "lambdaARN": "${self.triggers.lambda_arn}",
                "codeHookInterfaceVersion": "1.0"
              }
            }
          }
        }'

      echo "✅ Attached Lambda to Lex alias locale"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.create_lex_alias,
    aws_lambda_function.query_lex_handler
  ]
}
