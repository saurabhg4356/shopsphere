output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "cicd_deploy_role_arn" {
  value       = aws_iam_role.cicd_deploy.arn
  description = "Add this ARN to your GitHub Actions workflow as AWS_ROLE_ARN secret"
}