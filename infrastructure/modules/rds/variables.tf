variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group of EKS nodes — only they can reach the DB"
  type        = string
}

variable "db_instance_class" {
  description = "db.t3.micro is free-tier eligible. Use db.t3.small or larger in production."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "shopsphere"
}

variable "db_username" {
  type    = string
  default = "shopsphere_admin"
}

variable "db_password" {
  description = "Set this via TF_VAR_db_password env var — never hardcode passwords"
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Enable Multi-AZ for automatic failover. Set true in production."
  type        = bool
  default     = false  # false for dev to reduce cost
}

variable "skip_final_snapshot" {
  description = "Set false in production to keep a final snapshot before destroy"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental deletion. Set true in production."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}