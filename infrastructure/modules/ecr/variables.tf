variable "project_name" {
  type = string
}

variable "service_names" {
  description = "List of microservice names — one ECR repo is created for each"
  type        = list(string)
  default     = ["user-service", "product-service", "order-service"]
}

variable "tags" {
  type    = map(string)
  default = {}
}