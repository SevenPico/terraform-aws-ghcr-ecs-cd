## Module-specific variables for GHCR-ECS Deployment

variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token for accessing private container repositories"
  sensitive   = true
  default     = ""
}

variable "github_username" {
  type        = string
  description = "GitHub username for accessing private container repositories. For PAT authentication, use 'x-access-token'."
  default     = "x-access-token"
}

variable "create_github_credentials_secret" {
  type        = bool
  description = "Whether to create a secret for the GitHub credentials"
  default     = true
}

variable "github_credentials_secret_arn" {
  type        = string
  description = "ARN of an existing secret containing the GitHub credentials (if not creating a new one)"
  default     = ""
}

variable "services" {
  description = "Map of services with their ECS and container configurations"
  type = map(object({
    cluster_name      = string
    service_name      = string
    github_org        = string
    github_repo       = string
    initial_image_tag = string
    container_name    = string
  }))
  default = {}
}

variable "lambda_runtime" {
  type        = string
  description = "Runtime for the Lambda function"
  default     = "python3.9"
}

variable "lambda_timeout" {
  type        = number
  description = "Lambda function timeout in seconds"
  default     = 60 # Increased timeout to handle task definition updates
}

variable "lambda_memory_size" {
  type        = number
  description = "Lambda function memory size in MB"
  default     = 256 # Increased memory size for better performance
}

variable "preserve_if_disabled" {
  type        = bool
  description = "Whether to preserve secrets and SSM parameters when the module is disabled"
  default     = false
}

# Name override
variable "name_override" {
  type        = string
  description = "Override the name used for resource naming. Default is 'ghcr-ecs-cd' if not provided."
  default     = ""
}

# Observability variables
variable "create_dashboard" {
  type        = bool
  description = "Whether to create a CloudWatch dashboard for monitoring deployments"
  default     = true
}

variable "create_alarms" {
  type        = bool
  description = "Whether to create CloudWatch alarms for deployment failures"
  default     = true
}

variable "logs_retention_days" {
  type        = number
  description = "Number of days to retain Lambda function logs"
  default     = 14
}

# Webhook variables
variable "create_webhook_api" {
  type        = bool
  description = "Whether to create an API Gateway for GitHub webhook integration"
  default     = false
}

variable "enable_image_refresh" {
  type        = bool
  description = "Enable automatic container image refreshing when image with same tag is updated in registry"
  default     = true
}

# Dashboard configuration
variable "dashboard_widget_height" {
  type        = number
  description = "Height of dashboard widgets"
  default     = 6
}

variable "dashboard_lambda_metrics_width" {
  type        = number
  description = "Width of Lambda metrics widget in the dashboard"
  default     = 12
}

variable "dashboard_logs_width" {
  type        = number
  description = "Width of logs widget in the dashboard"
  default     = 24
}

variable "dashboard_ecs_metrics_width" {
  type        = number
  description = "Width of ECS metrics widget in the dashboard"
  default     = 12
}

variable "dashboard_events_width" {
  type        = number
  description = "Width of events widget in the dashboard"
  default     = 24
}

variable "dashboard_lambda_metrics_period" {
  type        = number
  description = "Period for Lambda metrics in the dashboard (in seconds)"
  default     = 300
}

variable "dashboard_events_period" {
  type        = number
  description = "Period for events metrics in the dashboard (in seconds)"
  default     = 60
}

variable "dashboard_logs_limit" {
  type        = number
  description = "Number of log entries to display in the dashboard"
  default     = 20
}

# Alarm configuration
variable "alarm_evaluation_periods" {
  type        = number
  description = "Number of periods to evaluate for the alarm"
  default     = 1
}

variable "alarm_period" {
  type        = number
  description = "Period for the alarm (in seconds)"
  default     = 60
}

variable "alarm_threshold" {
  type        = number
  description = "Threshold for the alarm"
  default     = 0
}

variable "alarm_datapoints_to_alarm" {
  type        = number
  description = "Number of datapoints that must be breaching to trigger the alarm"
  default     = 1
}

variable "alarm_actions" {
  type        = list(string)
  description = "List of ARNs to notify when the alarm transitions to ALARM state"
  default     = []
}

variable "ok_actions" {
  type        = list(string)
  description = "List of ARNs to notify when the alarm transitions to OK state"
  default     = []
}

variable "metric_namespace" {
  type        = string
  description = "Namespace for CloudWatch metrics"
  default     = "GHCR-ECS-Deployment"
}

# Note: Webhook secret is expected to be in the GitHub credentials secret
# with a key named 'webhook_secret'
