output "repository_urls" {
  value       = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
  description = "Map of service name to ECR URL. Used in CI/CD to push images."
}

output "registry_id" {
  value = values(aws_ecr_repository.services)[0].registry_id
}