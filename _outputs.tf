## Outputs for GHCR-ECS Deployment module

output "parameters" {
  description = "SSM Parameter resources created by this module"
  value       = aws_ssm_parameter.image_tag
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function that forces deployments"
  value       = try(aws_lambda_function.deploy[0].arn, null)
}

output "lambda_function_name" {
  description = "Name of the Lambda function that forces deployments"
  value       = try(aws_lambda_function.deploy[0].function_name, null)
}

output "github_credentials_secret_arn" {
  description = "ARN of the GitHub credentials secret"
  value       = local.github_credentials_secret_arn
}


output "github_credentials_access_policy_arn" {
  description = "ARN of the IAM policy that grants access to the GitHub credentials secret"
  value       = try(aws_iam_policy.github_credentials_access[0].arn, null)
}

output "eventbridge_rule_arns" {
  description = "ARNs of the EventBridge rules"
  value = {
    for name, rule in aws_cloudwatch_event_rule.parameter_change : name => rule.arn
  }
}

# Observability outputs
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard for monitoring deployments"
  value       = try(aws_cloudwatch_dashboard.deployments[0].dashboard_name, null)
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard for monitoring deployments"
  value       = try(aws_cloudwatch_dashboard.deployments[0].dashboard_arn, null)
}

output "lambda_errors_alarm_arn" {
  description = "ARN of the CloudWatch alarm for Lambda errors"
  value       = try(aws_cloudwatch_metric_alarm.lambda_errors[0].arn, null)
}

output "lambda_log_group_name" {
  description = "Name of the CloudWatch log group for Lambda logs"
  value       = try(aws_cloudwatch_log_group.lambda_logs[0].name, null)
}

output "successful_deployments_metric_name" {
  description = "Name of the CloudWatch metric for successful deployments"
  value       = try(aws_cloudwatch_log_metric_filter.successful_deployments[0].metric_transformation[0].name, null)
}

# GitHub Webhook outputs
output "github_webhook_url" {
  description = "URL for the GitHub webhook endpoint"
  value       = try("${aws_apigatewayv2_stage.webhook[0].invoke_url}/webhook", null)
}

output "github_webhook_api_id" {
  description = "ID of the API Gateway for GitHub webhook integration"
  value       = try(aws_apigatewayv2_api.webhook[0].id, null)
}

output "github_lambda_function_url" {
  description = "URL for directly invoking the GitHub-connected Lambda function"
  value       = try(aws_lambda_function_url.deploy[0].function_url, null)
}
