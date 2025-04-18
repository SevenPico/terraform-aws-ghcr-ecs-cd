## Main configuration for GHCR-ECS Deployment module
## This module provides continuous deployment infrastructure for ECS services 
## using GitHub Container Registry

module "ghcr_ecs_cd_label" {
  source  = "SevenPico/context/null"
  version = "2.0.0"

  # Inherit attributes from parent module but override name
  context = module.context.self
  name    = var.name_override != "" ? var.name_override : "ghcr-ecs-cd"
}

locals {
  # Normalize service names and create parameter paths
  service_parameters = {
    for name, config in var.services : name => {
      parameter_name  = "/version/ecs/${name}/${config.github_repo}"
      parameter_value = config.initial_image_tag
      service_config  = config
    }
  }

  # Determine which GitHub credentials secret to use with try() for safety
  github_credentials_secret_arn = var.create_github_credentials_secret ? try(aws_secretsmanager_secret.github_credentials[0].arn, "") : var.github_credentials_secret_arn
}

# Create SSM Parameters for each service's image tag
resource "aws_ssm_parameter" "image_tag" {
  for_each = (module.ghcr_ecs_cd_label.enabled || (!module.ghcr_ecs_cd_label.enabled && var.preserve_if_disabled)) ? local.service_parameters : {}

  name        = each.value.parameter_name
  description = "Container image tag for ${each.key} service"
  type        = "String"
  value       = each.value.parameter_value

  tags = module.ghcr_ecs_cd_label.tags

  # Prevent Terraform from managing the parameter value after creation
  # This allows operators to manually update the image tag without Terraform reverting it
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

# Create GitHub credentials secret if requested
resource "aws_secretsmanager_secret" "github_credentials" {
  count = (module.ghcr_ecs_cd_label.enabled || (!module.ghcr_ecs_cd_label.enabled && var.preserve_if_disabled)) && var.create_github_credentials_secret ? 1 : 0

  name                           = "${module.ghcr_ecs_cd_label.id}-github-credentials"
  description                    = "GitHub credentials for GHCR authentication and webhook verification"
  force_overwrite_replica_secret = true
  recovery_window_in_days        = 0 # Immediate deletion

  # Add force restore parameter to handle the secret being in deletion state
  lifecycle {
    ignore_changes = [
      # Don't update the secret metadata once created
      tags["LastUpdated"]
    ]
  }

  tags = module.ghcr_ecs_cd_label.tags
}

resource "aws_secretsmanager_secret_version" "github_credentials" {
  count = (module.ghcr_ecs_cd_label.enabled || (!module.ghcr_ecs_cd_label.enabled && var.preserve_if_disabled)) && var.create_github_credentials_secret && var.github_token != "" ? 1 : 0

  secret_id = aws_secretsmanager_secret.github_credentials[0].id

  # Store secret as JSON with username, password and webhook_secret keys
  secret_string = jsonencode({
    username       = var.github_username
    password       = var.github_token
    webhook_secret = "" # Placeholder to be updated manually
  })

  # Prevent overwrites once created
  lifecycle {
    ignore_changes = [
      secret_string
    ]
  }
}
