output "db_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "Connection string for your microservices. Store in AWS Secrets Manager (Step 7)."
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_port" {
  value = aws_db_instance.main.port
}