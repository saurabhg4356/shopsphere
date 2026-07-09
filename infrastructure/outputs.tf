output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "Run: aws eks update-kubeconfig --name <this_value> --region ap-south-1"
}

output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "Push Docker images here in Step 4"
}

output "rds_endpoint" {
  value       = module.rds.db_endpoint
  description = "PostgreSQL connection endpoint for your services"
}

output "cicd_deploy_role_arn" {
  value       = module.iam.cicd_deploy_role_arn
  description = "Add as AWS_ROLE_ARN secret in your GitHub repo settings"
}