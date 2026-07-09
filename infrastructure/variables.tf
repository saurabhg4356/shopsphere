variable "aws_region" {
  description = "AWS region. ap-south-1 = Mumbai (closest to India)"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "shopsphere"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "aws_account_id" {
  description = "Your 12-digit AWS account ID"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo in owner/repo format for CI/CD OIDC trust"
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_type" {
  description = "t3.medium = ~$0.05/hr. Two nodes = ~$70/month. Stop them when not in use."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_count" {
  type    = number
  default = 2
}

variable "node_min_count" {
  type    = number
  default = 1
}

variable "node_max_count" {
  type    = number
  default = 4
}

variable "db_instance_class" {
  description = "db.t3.micro is free-tier eligible for 12 months"
  type        = string
  default     = "db.t3.micro"
}

variable "db_password" {
  description = "RDS master password. Set via: export TF_VAR_db_password='yourpassword'"
  type        = string
  sensitive   = true
}