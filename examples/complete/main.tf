# Main configuration for the complete example

module "ecs_cluster" {
  source  = "cloudposse/ecs-cluster/aws"
  version = "0.9.0"
  context = module.context.legacy

  container_insights_enabled = true
}

# Container definition
module "container_definition" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.2"

  container_name  = "nginx"
  container_image = "nginx:latest"

  container_cpu    = 256
  container_memory = 512

  port_mappings = [
    {
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }
  ]

  repository_credentials = {
    credentialsParameter = module.ghcr_ecs_cd.github_credentials_secret_arn
  }
}

module "ecs_service" {
  source  = "SevenPicoForks/ecs-alb-service-task/aws"
  version = "2.4.2"
  context = module.context.self

  container_definition_json = module.container_definition.json_map_encoded_list
  ecs_cluster_arn           = module.ecs_cluster.arn

  # Network configuration
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc_subnets.private_subnet_ids
  security_group_ids = [module.alb.security_group_id]

  # Task settings
  task_cpu    = 256
  task_memory = 512

  # Service settings
  desired_count = 1

  # Load balancer settings
  ecs_load_balancers = {
    example = {
      container_name   = "nginx"
      container_port   = 80
      target_group_arn = module.alb.default_target_group_arn
      elb_name         = null
    }
  }
}

# Application Load Balancer
module "alb" {
  source  = "SevenPicoForks/alb/aws"
  version = "2.0.1"
  context = module.context.self

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc_subnets.private_subnet_ids
  security_group_ids = []

  internal                  = true
  http_enabled              = false
  https_enabled             = true
  https_port                = 443
  https_ingress_cidr_blocks = ["10.0.0.0/16"] # Using default VPC CIDR
  certificate_arn           = module.ssl_certificate.acm_certificate_arn

  access_logs_enabled      = false
  access_logs_prefix       = null
  access_logs_s3_bucket_id = "placeholder-not-used"

  default_target_group_enabled = true
  target_group_port            = 80
  target_group_protocol        = "HTTP"
  target_group_target_type     = "ip"

  health_check_path                = "/"
  health_check_port                = "traffic-port"
  health_check_protocol            = "HTTP"
  health_check_timeout             = 5
  health_check_healthy_threshold   = 3
  health_check_unhealthy_threshold = 3
  health_check_interval            = 30
  health_check_matcher             = "200-399"
}

module "ghcr_ecs_cd" {
  source = "../../"

  # Context
  context = module.context.self

  # GitHub credentials
  github_token    = var.github_token
  github_username = var.github_username

  # Service configuration
  services = {
    "${module.context.id}" = {
      cluster_name      = module.ecs_cluster.name
      service_name      = module.ecs_service.service_name
      github_org        = var.github_org
      github_repo       = var.github_repo
      initial_image_tag = var.initial_image_tag
      container_name    = "nginx"
    }
  }

  # Webhook settings
  create_webhook_api   = true
  enable_image_refresh = true

  # Observability settings
  create_dashboard    = true
  create_alarms       = true
  logs_retention_days = 14
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
}
