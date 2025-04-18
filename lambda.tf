# Lambda function for forcing new ECS deployments (Python implementation)
data "archive_file" "lambda_zip" {
  count = module.context.enabled ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source_dir  = "${path.module}/lambda"
}

resource "aws_lambda_function" "deploy" {
  count = module.context.enabled ? 1 : 0

  function_name = module.ghcr_ecs_cd_label.id
  description   = "Forces new ECS deployments when SSM Parameters change or GitHub webhook events are received"
  role          = aws_iam_role.lambda[0].arn
  handler       = "lambda.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.lambda_zip[0].output_path
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256

  environment {
    variables = {
      GITHUB_CREDENTIALS_SECRET_ARN = local.github_credentials_secret_arn,
      SERVICE_MAP                   = jsonencode(local.service_parameters)
    }
  }

  tags = module.ghcr_ecs_cd_label.tags
}
