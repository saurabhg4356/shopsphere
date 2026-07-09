variable "project_name" {
  type = string
}

variable "aws_account_id" {
  description = "Your 12-digit AWS account ID (run: aws sts get-caller-identity)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo in owner/repo format e.g. your-username/shopsphere"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}