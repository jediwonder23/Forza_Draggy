terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "forza-backend"
    key            = "terraform/state.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:599801163540:key/d116cc92-3ea4-4e07-8913-590c1bc3f1df"
  }
}

provider "aws" {
  region = "us-east-1"
}

# -------------------- Cognito ----------------------
resource "aws_cognito_user_pool" "forza" {
  name = "forza-user-pool"
  auto_verified_attributes = ["email"]

  schema {
    name = "email"
    attribute_data_type = "String"
    required = true
    mutable = false
  }
}

resource "aws_cognito_user_pool_client" "forza_client" {
  name         = "forza-client"
  user_pool_id = aws_cognito_user_pool.forza.id
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["email", "openid"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls = ["https://your-app-domain/callback"]
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.forza.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.forza_client.id
}

# -------------------- DynamoDB ----------------------
resource "aws_dynamodb_table" "runs" {
  name         = "ForzaRunLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "run_id"
  attribute {
    name = "run_id"
    type = "S"
  }
}

# -------------------- IAM Roles & Policies ----------------------
resource "aws_iam_role" "lambda_exec" {
  name = "ForzaLambdaRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_dynamo" {
  name = "ForzaLambdaDynamoPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = ["dynamodb:PutItem", "dynamodb:Scan"],
      Effect   = "Allow",
      Resource = aws_dynamodb_table.runs.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_dynamo.arn
}

# -------------------- Archive Lambdas ----------------------
resource "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/Lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "archive_file" "get_runs_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/Lambda"
  output_path = "${path.module}/get_runs_lambda.zip"
}

# -------------------- Lambda Functions ----------------------
resource "aws_lambda_function" "log_run" {
  filename         = archive_file.lambda_zip.output_path
  function_name    = "LogForzaRun"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.9"
  source_code_hash = archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_function" "get_runs" {
  filename         = archive_file.get_runs_lambda_zip.output_path
  function_name    = "GetForzaRuns"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "get_runs_handler.handler"
  runtime          = "python3.9"
  source_code_hash = archive_file.get_runs_lambda_zip.output_base64sha256
}

# -------------------- API Gateway ----------------------
resource "aws_apigatewayv2_api" "forza_api" {
  name          = "ForzaAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.forza_api.id
  name             = "CognitoJWT"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {
    audience = [aws_cognito_user_pool_client.forza_client.id]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.forza.id}"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                  = aws_apigatewayv2_api.forza_api.id
  integration_type        = "AWS_PROXY"
  integration_uri         = aws_lambda_function.log_run.invoke_arn
  payload_format_version  = "2.0"
}

resource "aws_apigatewayv2_route" "post_run" {
  api_id    = aws_apigatewayv2_api.forza_api.id
  route_key = "POST /run"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_integration" "get_runs_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.forza_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_runs.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_runs" {
  api_id             = aws_apigatewayv2_api.forza_api.id
  route_key          = "GET /runs"
  target             = "integrations/${aws_apigatewayv2_integration.get_runs_lambda_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.forza_api.id
  name        = "$default"
  auto_deploy = true
}

# -------------------- Permissions ----------------------
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_run.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.forza_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigw_invoke_get_runs" {
  statement_id  = "AllowAPIGatewayInvokeGetRuns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_runs.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.forza_api.execution_arn}/*/*"
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.forza_api.api_endpoint
}
