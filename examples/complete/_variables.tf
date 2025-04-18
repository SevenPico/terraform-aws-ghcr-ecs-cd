# VPC Variables
variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones to use"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Route53 Variables
variable "route53_zone_id" {
  type        = string
  description = "ID of the Route53 zone to create records in"
  default     = ""
}

# SSL Certificate Variables
variable "kms_key_deletion_window_in_days" {
  type        = number
  description = "Duration in days after which the key is deleted after destruction of the resource"
  default     = 30
}

variable "kms_key_enable_key_rotation" {
  type        = bool
  description = "Specifies whether key rotation is enabled"
  default     = true
}

# GitHub Variables
variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token for accessing private container repositories"
  sensitive   = true
  default     = ""
}

variable "github_username" {
  type        = string
  description = "GitHub username for accessing private container repositories"
  default     = "x-access-token"
}

variable "github_org" {
  type        = string
  description = "GitHub organization name"
  default     = "example-org"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
  default     = "example-repo"
}

variable "initial_image_tag" {
  type        = string
  description = "Initial container image tag to deploy"
  default     = "latest"
}

# Alarm Variables
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
