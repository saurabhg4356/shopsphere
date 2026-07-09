output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "Copy this into the backend block in infrastructure/main.tf"
}

output "lock_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "Copy this into the backend block in infrastructure/main.tf"
}