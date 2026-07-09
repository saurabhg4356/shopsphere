# ── DB subnet group ───────────────────────────────────────────────────────────
# RDS requires subnets in at least 2 AZs for Multi-AZ
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

# ── Security group: only EKS nodes can reach the DB ───────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL access from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]  # Not open to internet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-sg"
  })
}

# ── RDS PostgreSQL ─────────────────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = "17.8"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100     # Auto-scales up to 100 GB if needed
  storage_type          = "gp3"
  storage_encrypted     = true    # Encrypts data at rest using AWS KMS

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  multi_az            = var.multi_az           # Set to true in production for failover
  publicly_accessible = false                  # Never expose DB to internet
  skip_final_snapshot = var.skip_final_snapshot

  backup_retention_period = 7      # 7-day automated backups
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  deletion_protection = var.deletion_protection

  tags = merge(var.tags, {
    Name = "${var.project_name}-postgres"
  })
}