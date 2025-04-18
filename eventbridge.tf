## EventBridge rules for GHCR-ECS Deployment module
## These rules detect changes to SSM parameters and trigger the Lambda function

# Create EventBridge rules to detect parameter changes
resource "aws_cloudwatch_event_rule" "parameter_change" {
  for_each = module.context.enabled ? local.service_parameters : {}

  name        = "${module.ghcr_ecs_cd_label.id}-${each.key}"
  description = "Detect changes to ${each.key} image tag parameter"

  event_pattern = jsonencode({
    source      = ["aws.ssm"],
    detail-type = ["Parameter Store Change"],
    detail = {
      name      = [each.value.parameter_name],
      operation = ["Update"]
    }
  })

  tags = module.ghcr_ecs_cd_label.tags
}

# Create EventBridge targets to invoke Lambda function
resource "aws_cloudwatch_event_target" "invoke_lambda" {
  for_each = module.context.enabled ? local.service_parameters : {}

  rule      = aws_cloudwatch_event_rule.parameter_change[each.key].name
  target_id = "InvokeLambda"
  arn       = aws_lambda_function.deploy[0].arn
}

# Allow EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  for_each = module.context.enabled ? local.service_parameters : {}

  statement_id  = "AllowExecutionFromEventBridge${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deploy[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.parameter_change[each.key].arn
}
