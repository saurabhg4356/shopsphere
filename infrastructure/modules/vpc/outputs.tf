output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID used by EKS and RDS modules"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnet IDs (for ALB, NAT Gateway)"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Private subnet IDs (for EKS nodes, RDS)"
}