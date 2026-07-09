output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "Use this to configure kubectl: aws eks update-kubeconfig --name <cluster_name>"
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  value     = aws_eks_cluster.main.certificate_authority[0].data
  sensitive = true
}

output "node_security_group_id" {
  value       = aws_security_group.eks_nodes.id
  description = "Used by RDS module to allow inbound from EKS nodes"
}