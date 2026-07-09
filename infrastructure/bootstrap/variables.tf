variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state. Change this — bucket names are global."
  type        = string
  default     = "shopsphere-tfstate-922806890560"
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "shopsphere-tfstate-locks"
}