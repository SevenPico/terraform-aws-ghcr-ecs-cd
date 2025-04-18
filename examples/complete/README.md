# Complete GitHub Container Registry ECS Continuous Deployment Example

This example demonstrates a complete setup of the GitHub Container Registry ECS Continuous Deployment module.

## Features Demonstrated

- VPC setup with public and private subnets
- ECS cluster and service configuration
- Application Load Balancer setup
- Route53 DNS configuration with A record alias
- SSL certificate provisioning
- GitHub Container Registry integration
- Continuous deployment pipeline
- CloudWatch monitoring and alerting

## Usage

To run this example, you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Or if using Terragrunt:

```bash
$ terragrunt init
$ terragrunt plan
$ terragrunt apply
```

Note that this example may create resources which cost money. Run `terraform destroy` or `terragrunt destroy` when you don't need these resources.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_cidr_block | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| availability_zones | List of availability zones to use | `list(string)` | `["us-east-1a", "us-east-1b", "us-east-1c"]` | no |
| route53_zone_id | ID of the Route53 zone to create records in | `string` | `""` | yes |
| github_token | GitHub Personal Access Token for accessing private container repositories | `string` | `""` | yes |
| github_username | GitHub username for accessing private container repositories | `string` | `"x-access-token"` | no |
| github_org | GitHub organization name | `string` | `"example-org"` | no |
| github_repo | GitHub repository name | `string` | `"example-repo"` | no |
| initial_image_tag | Initial container image tag to deploy | `string` | `"latest"` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| private_subnet_ids | IDs of the private subnets |
| public_subnet_ids | IDs of the public subnets |
| ecs_cluster_name | Name of the ECS cluster |
| ecs_service_name | Name of the ECS service |
| ssm_parameters | SSM Parameter resources created by the module |
| lambda_function_arn | ARN of the Lambda function that forces deployments |
| lambda_function_name | Name of the Lambda function that forces deployments |
| github_credentials_secret_arn | ARN of the GitHub credentials secret |
| github_webhook_url | URL for the GitHub webhook endpoint |
| domain_name | Domain name for the application |
| alb_dns_name | DNS name of the ALB |
| certificate_arn | ARN of the SSL certificate |
