# Main configuration for the complete example

module "ecs_cluster" {
  source  = "registry.terraform.io/SevenPico/ecs-cluster/aws"
  version = "1.0.0"
  context = module.context.self

  container_insights_enabled = true
}

module "ecs_service" {
  source  = "registry.terraform.io/SevenPico/ecs-service/aws"
  version = "1.0.0"
  context = module.context.self

  cluster_arn = module.ecs_cluster.arn
  
  # Container definition
  container_name  = "example"
  container_image = "ghcr.io/${var.github_org}/${var.github_repo}:${var.initial_image_tag}"
  container_port  = 80
  
  # Network configuration
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc_subnets.private_subnet_ids
  security_groups = [aws_security_group.ecs_service.id]
  
  # Task definition
  task_cpu    = 256
  task_memory = 512
}

# Application Load Balancer
module "alb" {
  source  = "registry.terraform.io/SevenPico/alb/aws"
  version = "1.0.0"
  context = module.context.self

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc_subnets.public_subnet_ids
  security_groups = [aws_security_group.alb.id]

  target_groups = {
    main = {
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200-399"
      }
      targets = {
        ecs_service = {
          target_id = module.ecs_service.service_id
          port      = 80
        }
      }
    }
  }

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
}

resource "aws_security_group" "ecs_service" {
  name        = "${module.context.id}-ecs-service"
  description = "Security group for ECS service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.context.tags
}

resource "aws_security_group" "alb" {
  name        = "${module.context.id}-alb"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.context.tags
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
      service_name      = module.ecs_service.name
      github_org        = var.github_org
      github_repo       = var.github_repo
      initial_image_tag = var.initial_image_tag
      container_name    = "example"
    }
  }
  
  # Webhook settings
  create_webhook_api    = true
  enable_image_refresh  = true
  
  # Observability settings
  create_dashboard    = true
  create_alarms       = true
  logs_retention_days = 14
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
}
