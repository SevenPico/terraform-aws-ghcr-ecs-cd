## API Gateway for GitHub webhooks
## This file creates resources to handle container image update notifications from GitHub

# API Gateway for webhook integration
resource "aws_apigatewayv2_api" "webhook" {
  count = module.context.enabled && var.create_webhook_api ? 1 : 0

  name          = "${module.ghcr_ecs_cd_label.id}-webhook"
  protocol_type = "HTTP"
  description   = "Webhook endpoint for GitHub Container Registry image updates"

  cors_configuration {
    allow_origins = ["https://github.com"]
    allow_methods = ["POST"]
    allow_headers = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-GitHub-Delivery", "X-Hub-Signature-256"]
    max_age       = 300
  }

  tags = module.ghcr_ecs_cd_label.tags
}

# Default stage for the API
resource "aws_apigatewayv2_stage" "webhook" {
  count = module.context.enabled && var.create_webhook_api ? 1 : 0

  api_id      = aws_apigatewayv2_api.webhook[0].id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.webhook_logs[0].arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      path               = "$context.path"
      routeKey           = "$context.routeKey"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      integrationLatency = "$context.integrationLatency"
    })
  }

  tags = module.ghcr_ecs_cd_label.tags
}

# Webhook endpoint route
resource "aws_apigatewayv2_route" "webhook" {
  count = module.context.enabled && var.create_webhook_api ? 1 : 0

  api_id    = aws_apigatewayv2_api.webhook[0].id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.webhook[0].id}"
}

# Integration with Lambda function
resource "aws_apigatewayv2_integration" "webhook" {
  count = module.context.enabled && var.create_webhook_api ? 1 : 0

  api_id                 = aws_apigatewayv2_api.webhook[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.deploy[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# CloudWatch log group for API Gateway logs
resource "aws_cloudwatch_log_group" "webhook_logs" {
  count = module.context.enabled && var.create_webhook_api ? 1 : 0

  name              = "/aws/apigateway/${module.ghcr_ecs_cd_label.id}-webhook"
  retention_in_days = var.logs_retention_days

  tags = module.ghcr_ecs_cd_label.tags
}

# Allow API Gateway to invoke Lambda function
resource "aws_lambda_permission" "allow_api_gateway" {
  count = module.context.enabled && var.create_webhook_api ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deploy[0].function_name
  principal     = "apigateway.amazonaws.com"

  # The source ARN specifies that this resource can be triggered by any stage of the API Gateway
  source_arn = "${aws_apigatewayv2_api.webhook[0].execution_arn}/*/*/webhook"
}

# Add Lambda function URL for direct invocation
resource "aws_lambda_function_url" "deploy" {
  count = module.context.enabled && var.enable_image_refresh ? 1 : 0

  function_name      = aws_lambda_function.deploy[0].function_name
  authorization_type = "NONE"
}

# Instructions for setting up the GitHub webhook
resource "null_resource" "webhook_setup_instructions" {
  count = module.context.enabled && var.create_webhook_api ? 1 : 0

  # Only trigger when the webhook URL changes, not on every apply
  triggers = {
    webhook_url = aws_apigatewayv2_stage.webhook[0].invoke_url
  }

  # Output the instructions to the user
  provisioner "local-exec" {
    command = <<-EOT
      echo "### GitHub Webhook Setup Instructions ###"
      echo ""
      echo "1. Add a 'webhook_secret' field to your GitHub credentials secret in Secrets Manager"
      echo "   (The secret is located at: ${local.github_credentials_secret_arn})"
      echo ""
      echo "2. Make sure your GitHub credentials secret has this format:"
      echo "   {"
      echo "     \"username\": \"x-access-token\","
      echo "     \"password\": \"ghp_your_github_token\","
      echo "     \"webhook_secret\": \"your_webhook_secret\""
      echo "   }"
      echo ""
      echo "3. Configure a webhook in your GitHub container registry repository:"
      echo "   - Webhook URL: ${aws_apigatewayv2_stage.webhook[0].invoke_url}/webhook"
      echo "   - Content type: application/json"
      echo "   - Secret: The same value you added as webhook_secret to the GitHub credentials secret"
      echo "   - Events: Package > Package published"
      echo ""
      echo "This will enable automatic redeployment when a new container image is published"
      echo "to the GitHub Container Registry, even if the tag remains the same."
      echo "############################################"
    EOT
  }
}
