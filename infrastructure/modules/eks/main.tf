# ── Security group for the EKS cluster ───────────────────────────────────────
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Control plane security group"
  vpc_id      = var.vpc_id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-cluster-sg"
  })
}

# ── Security group for worker nodes ───────────────────────────────────────────
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "Worker node security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name                                              = "${var.project_name}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
  })
}

# Allow nodes to communicate with each other
resource "aws_security_group_rule" "nodes_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Allow control plane to talk to nodes (for kubelet, health checks)
resource "aws_security_group_rule" "cluster_to_nodes" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Allow nodes to talk to control plane API server
resource "aws_security_group_rule" "nodes_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_cluster.id
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = var.eks_cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true   # Nodes communicate with API server privately
    endpoint_public_access  = true   # You can run kubectl from your laptop
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  # Enable control plane logging to CloudWatch
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [var.eks_cluster_role_arn]

  tags = merge(var.tags, {
    Name = "${var.project_name}-cluster"
  })
}

# ── Managed Node Group ────────────────────────────────────────────────────────
# AWS manages patching, scaling, and replacement of nodes
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids  # Nodes in private subnets

  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_count
    min_size     = var.node_min_count
    max_size     = var.node_max_count
  }

  update_config {
    max_unavailable = 1  # Rolling update — always keep at least N-1 nodes available
  }

  # Use the latest Amazon Linux 2 EKS-optimised AMI
  ami_type = "AL2_x86_64"

  labels = {
    role = "application"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-node-group"
  })
}