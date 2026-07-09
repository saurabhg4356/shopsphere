terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend — run bootstrap/ first to create the S3 bucket and DynamoDB table
  # Then fill in your bucket name and region below
  backend "s3" {
    bucket         = "shopsphere-tfstate-922806890560"   # ← change this
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "shopsphere-tfstate-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  tags         = local.common_tags
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source         = "./modules/iam"
  project_name   = var.project_name
  aws_account_id = var.aws_account_id
  github_repo    = var.github_repo
  tags           = local.common_tags
}

# ── ECR ───────────────────────────────────────────────────────────────────────
module "ecr" {
  source        = "./modules/ecr"
  project_name  = var.project_name
  service_names = ["user-service", "product-service", "order-service"]
  tags          = local.common_tags
}

# ── EKS ───────────────────────────────────────────────────────────────────────
module "eks" {
  source       = "./modules/eks"
  project_name = var.project_name

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_node_role_arn    = module.iam.eks_node_role_arn

  node_instance_type = var.node_instance_type
  node_desired_count = var.node_desired_count
  node_min_count     = var.node_min_count
  node_max_count     = var.node_max_count
  kubernetes_version = var.kubernetes_version

  tags = local.common_tags
}

# ── RDS ───────────────────────────────────────────────────────────────────────
module "rds" {
  source       = "./modules/rds"
  project_name = var.project_name

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  eks_node_security_group_id = module.eks.node_security_group_id

  db_instance_class   = var.db_instance_class
  db_password         = var.db_password
  deletion_protection = false   # Set true in production
  skip_final_snapshot = true    # Set false in production

  tags = local.common_tags
}