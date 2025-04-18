## IAM resources for GHCR-ECS Deployment module
## These resources provide the necessary permissions for the Lambda function

# IAM role for Lambda function
resource "aws_iam_role" "lambda" {
  count = module.context.enabled ? 1 : 0

  name        = "${module.ghcr_ecs_cd_label.id}-lambda-role"
  description = "Role for the ECS deployment Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = module.ghcr_ecs_cd_label.tags
}

# Policy to allow Lambda to update ECS services
resource "aws_iam_policy" "lambda_ecs" {
  count = module.context.enabled ? 1 : 0

  name        = "${module.ghcr_ecs_cd_label.id}-lambda-ecs-policy"
  description = "Allow Lambda to update ECS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:PassedToService" : "ecs-tasks.amazonaws.com"
          }
        }
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ssm:GetParameter"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:ssm:*:*:parameter/ecs/*",
          "arn:aws:ssm:*:*:parameter/version/ecs/*"
        ]
      },
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect = "Allow"
        Resource = [
          try(aws_secretsmanager_secret.github_credentials[0].arn, var.github_credentials_secret_arn),
          "arn:aws:secretsmanager:*:*:secret:${module.ghcr_ecs_cd_label.id}-github-credentials-*"
        ]
      }
    ]
  })

  tags = module.ghcr_ecs_cd_label.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_ecs" {
  count = module.context.enabled ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = aws_iam_policy.lambda_ecs[0].arn
}

# Create a policy for ECS execution role to access the GitHub credentials
resource "aws_iam_policy" "github_credentials_access" {
  count = module.context.enabled ? 1 : 0

  name        = "${module.ghcr_ecs_cd_label.id}-github-credentials-access-policy-v2"
  description = "Allow ECS task execution role to access GitHub credentials secret in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect = "Allow"
        Resource = [
          try(aws_secretsmanager_secret.github_credentials[0].arn, var.github_credentials_secret_arn),
          "arn:aws:secretsmanager:*:*:secret:${module.ghcr_ecs_cd_label.id}-github-credentials-*"
        ]
      }
    ]
  })

  tags = module.ghcr_ecs_cd_label.tags
}
