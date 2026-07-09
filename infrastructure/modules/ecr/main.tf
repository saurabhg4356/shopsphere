# Create one ECR repository for each microservice
resource "aws_ecr_repository" "services" {
  for_each = toset(var.service_names)

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE"  # Allows :latest tag to be overwritten

  image_scanning_configuration {
    scan_on_push = true  # Automatically scans for CVEs on every push — free with ECR
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

# Lifecycle policy: keep only the last 10 images per repo
# Prevents unbounded storage growth — old images are cleaned up automatically
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}