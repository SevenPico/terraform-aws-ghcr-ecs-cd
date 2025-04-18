# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc_subnets.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc_subnets.public_subnet_ids
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.service_name
}

# GHCR-ECS-CD Outputs
output "ssm_parameters" {
  description = "SSM Parameter resources created by the module"
  value       = module.ghcr_ecs_cd.parameters
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function that forces deployments"
  value       = module.ghcr_ecs_cd.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function that forces deployments"
  value       = module.ghcr_ecs_cd.lambda_function_name
}

output "github_credentials_secret_arn" {
  description = "ARN of the GitHub credentials secret"
  value       = module.ghcr_ecs_cd.github_credentials_secret_arn
}

output "github_credentials_access_policy_arn" {
  description = "ARN of the IAM policy that grants access to the GitHub credentials secret"
  value       = module.ghcr_ecs_cd.github_credentials_access_policy_arn
}

output "eventbridge_rule_arns" {
  description = "ARNs of the EventBridge rules"
  value       = module.ghcr_ecs_cd.eventbridge_rule_arns
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard for monitoring deployments"
  value       = module.ghcr_ecs_cd.dashboard_name
}

output "lambda_errors_alarm_arn" {
  description = "ARN of the CloudWatch alarm for Lambda errors"
  value       = module.ghcr_ecs_cd.lambda_errors_alarm_arn
}

output "github_webhook_url" {
  description = "URL for the GitHub webhook endpoint"
  value       = module.ghcr_ecs_cd.github_webhook_url
}

# Route53 Outputs
output "domain_name" {
  description = "Domain name for the application"
  value       = module.context.domain_name
}

output "alias_record_name" {
  description = "The A record alias name"
  value       = try(aws_route53_record.alias[0].name, null)
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = module.alb.alb_zone_id
}

# SSL Certificate Outputs
output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = module.ssl_certificate.acm_certificate_arn
}
