# The AWS region currently being used.
data "aws_region" "current" {
  count = module.context.enabled ? 1 : 0
}

# The AWS account id
data "aws_caller_identity" "current" {
  count = module.context.enabled ? 1 : 0
}

# The AWS partition (commercial or govcloud)
data "aws_partition" "current" {
  count = module.context.enabled ? 1 : 0
}

locals {
  arn_prefix = "arn:${try(data.aws_partition.current[0].partition, "")}"
  account_id = try(data.aws_caller_identity.current[0].account_id, "")
  region     = try(data.aws_region.current[0].name, "")
}
