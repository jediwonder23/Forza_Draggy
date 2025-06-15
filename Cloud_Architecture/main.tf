terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket = var.tf_state_bucket
    key    = "terraform/forza-backend.tfstate"
    region = var.aws_region
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

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
  allowed_oauth_scopes = ["email","openid"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls = ["https://your-app-domain/callback"]
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.forza.id
}
output "cognito_client_id" {
  value = aws_cognito_user_pool_client.forza_client.id
}

resource "aws_dynamodb_table" "runs" {
  name         = "ForzaRunLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "run_id"
  attribute {
    name = "run_id"
    type = "S"
  }
}

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
      Action   = ["dynamodb:PutItem"],
      Effect   = "Allow",
      Resource = aws_dynamodb_table.runs.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_attach" {
  role = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_dynamo.arn
}

resource "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "log_run" {
  filename         = archive_file.lambda_zip.output_path
  function_name    = "LogForzaRun"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.9"
  source_code_hash = archive_file.lambda_zip.output_base64sha256
}

resource "aws_apigatewayv2_api" "forza_api" {
  name          = "ForzaAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id = aws_apigatewayv2_api.forza_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.log_run.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_run" {
  api_id    = aws_apigatewayv2_api.forza_api.id
  route_key = "POST /run"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.forza_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_run.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.forza_api.execution_arn}/*/*"
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.forza_api.api_endpoint
}
