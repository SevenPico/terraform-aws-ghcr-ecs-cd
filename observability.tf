## Observability resources for GHCR-ECS Deployment module
## This file adds CloudWatch dashboard and alarms for deployment monitoring

# Create a CloudWatch Dashboard for monitoring deployments
resource "aws_cloudwatch_dashboard" "deployments" {
  count = module.ghcr_ecs_cd_label.enabled && var.create_dashboard ? 1 : 0

  dashboard_name = module.ghcr_ecs_cd_label.id
  dashboard_body = jsonencode({
    widgets = [
      # Lambda metrics widget
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.deploy[0].function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = local.region
          title   = "Lambda Deployment Function Metrics"
          period  = 300
        }
      },
      # Latest Lambda logs
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '/aws/lambda/${aws_lambda_function.deploy[0].function_name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = local.region
          title  = "Latest Deployment Logs"
          view   = "table"
        }
      },
      # ECS Service Metrics 
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = concat(
            [for name, config in var.services :
              ["AWS/ECS", "CPUUtilization", "ServiceName", config.service_name, "ClusterName", config.cluster_name]
            ],
            [for name, config in var.services :
              [".", "MemoryUtilization", "ServiceName", config.service_name, "ClusterName", config.cluster_name]
            ]
          )
          view    = "timeSeries"
          stacked = false
          region  = local.region
          title   = "ECS Service Metrics"
          period  = 300
        }
      },
      # Parameter Change Events
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          metrics = [
            for name, _ in var.services :
            ["AWS/Events", "Invocations", "RuleName", "${module.ghcr_ecs_cd_label.id}-${name}"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = local.region
          title   = "Parameter Change Events"
          period  = 60
        }
      }
    ]
  })
}

# Add CloudWatch Alarms for failed deployments
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = module.ghcr_ecs_cd_label.enabled && var.create_alarms ? 1 : 0

  alarm_name          = "${module.ghcr_ecs_cd_label.id}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  datapoints_to_alarm = 1
  alarm_description   = "This alarm monitors for errors in the deployment Lambda function"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
  treat_missing_data  = "ignore"

  dimensions = {
    FunctionName = aws_lambda_function.deploy[0].function_name
  }

  tags = module.ghcr_ecs_cd_label.tags
}

# CloudWatch Log Group with explicit configuration for the Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  count = module.ghcr_ecs_cd_label.enabled ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.deploy[0].function_name}"
  retention_in_days = var.logs_retention_days

  tags = module.ghcr_ecs_cd_label.tags
}

# Add CloudWatch Log Metric Filter to detect successful deployments
resource "aws_cloudwatch_log_metric_filter" "successful_deployments" {
  count = module.ghcr_ecs_cd_label.enabled && var.create_alarms ? 1 : 0

  name           = "${module.ghcr_ecs_cd_label.id}-successful-deployments"
  pattern        = "Deployment initiated successfully"
  log_group_name = aws_cloudwatch_log_group.lambda_logs[0].name

  metric_transformation {
    name          = "${module.ghcr_ecs_cd_label.id}_SuccessfulDeployments"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = "0"
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}
