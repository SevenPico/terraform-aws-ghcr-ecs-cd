# GitHub Container Registry ECS Continuous Deployment Module

This module provides automated deployment infrastructure for ECS services using GitHub Container Registry.

## Features

- Manages GitHub Container Registry authentication via GitHub credentials
- Stores container image tags in SSM Parameters
- Provides Lambda function to force ECS deployments
- Creates EventBridge rules for automatic updates on parameter changes
- Includes built-in observability with CloudWatch dashboards and alarms
- Supports building and deploying from feature branches using a consistent tag pattern

## Usage

```hcl
module "ecs_deployment" {
  source = "SevenPico/ghcr-ecs-cd/aws"
  
  # Context
  context = module.context.self
  
  # GitHub credentials
  github_token = var.github_token
  github_username = "x-access-token"
  
  # Service configuration
  services = {
    "example-service" = {
      cluster_name     = module.ecs_cluster.name
      service_name     = module.ecs_service.service_name
      github_org       = "your-org"
      github_repo      = "your-repo"
      initial_image_tag = "latest"
      container_name   = "example"
    }
  }
  
  # Observability settings
  create_dashboard = true
  create_alarms = true
  logs_retention_days = 14
}
```

## Branch-Based Deployments

This module supports different deployment mechanisms based on the branch or tag pattern:

- **Main/Develop Branch**: Builds from main or develop branches use the tag provided in the webhook payload.
- **Version Tags**: When building from a specific version tag, that tag is used directly.
- **Feature Branches**: When building from a branch with the format `feature/<branch-name>`, the image is tagged as `feature-<branch-name>`.

Feature branch support allows developers to deploy their in-progress work for testing. Subsequent commits to the same feature branch will update the same deployment, making it ideal for continuous testing during development.

### GitHub Actions Configuration

To use feature branch deployments in your GitHub Actions workflow:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches:
      - main
      - develop
      - 'feature/**'
    tags:
      - 'v*'

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      # ... other steps ...
      
      - name: Extract branch/tag name for Docker tag
        id: extract_name
        shell: bash
        run: |
          if [[ $GITHUB_REF == refs/tags/* ]]; then
            # For version tags
            echo "TAG=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
          elif [[ $GITHUB_REF == refs/heads/feature/* ]]; then
            # For feature branches, use format feature-branchname
            BRANCH=${GITHUB_REF#refs/heads/}
            echo "TAG=feature-${BRANCH#feature/}" >> $GITHUB_OUTPUT
          else
            # For main/develop
            echo "TAG=${GITHUB_REF#refs/heads/}" >> $GITHUB_OUTPUT
          fi
      
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ steps.extract_name.outputs.TAG }}
          # ... other configuration ...
```

## Testing Deployment

To test the EventBridge-based deployment mechanism:

1. Get the parameter name from the module output:
```bash
PARAMETER_NAME=$(terraform output -raw module.ecs_deployment.parameters.example-service.name)
```

2. Update the parameter to trigger a deployment:
```bash
aws ssm put-parameter --name "$PARAMETER_NAME" --value "new-tag" --type String --overwrite
```

3. Monitor the deployment in the CloudWatch dashboard:
```bash
DASHBOARD_NAME=$(terraform output -raw module.ecs_deployment.dashboard_name)
echo "Visit the deployment dashboard: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${DASHBOARD_NAME}"
```

4. Check ECS service deployment status:
```bash
CLUSTER_NAME=$(terraform output -raw module.ecs_cluster.name)
SERVICE_NAME=$(terraform output -raw module.ecs_service.service_name)
aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query "services[0].deployments"
```

## Observability

This module creates the following observability resources:

1. **CloudWatch Dashboard**: Displays Lambda function metrics, ECS service metrics, parameter change events, and the latest deployment logs.

2. **CloudWatch Alarms**: Triggers on Lambda errors during deployment operations.

3. **CloudWatch Log Metric Filter**: Captures successful deployments as CloudWatch metrics.

4. **CloudWatch Log Group**: Configured with retention policy for Lambda function logs.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| github_token | GitHub Personal Access Token for accessing private repos | `string` | `""` | no |
| github_username | GitHub username for authentication | `string` | `"x-access-token"` | no |
| services | Map of services with ECS and container configurations | `map(object)` | `{}` | yes |
| create_dashboard | Whether to create a CloudWatch dashboard | `bool` | `true` | no |
| create_alarms | Whether to create CloudWatch alarms | `bool` | `true` | no |
| logs_retention_days | Number of days to retain logs | `number` | `14` | no |

## Outputs

| Name | Description |
|------|-------------|
| parameters | SSM Parameter resources created by this module |
| lambda_function_arn | ARN of the Lambda function |
| dashboard_name | Name of the CloudWatch dashboard |
| lambda_errors_alarm_arn | ARN of the CloudWatch alarm for Lambda errors |
| successful_deployments_metric_name | Name of the successful deployments metric |
