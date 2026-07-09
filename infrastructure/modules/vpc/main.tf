data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true  # Required for EKS node registration

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
    # These tags are required by the AWS Load Balancer Controller (Step 4)
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  })
}

# ── Public subnets (one per AZ) ───────────────────────────────────────────────
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Nodes in public subnet get a public IP — needed for internet access without NAT
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-${count.index + 1}"
    # ALB controller discovers subnets via these tags
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })
}

# ── Private subnets (one per AZ) ─────────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

# ── Elastic IP for NAT Gateway ────────────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

# ── NAT Gateway (in first public subnet) ──────────────────────────────────────
# Private subnet resources (EKS nodes, RDS) use this to reach the internet
# e.g. to pull Docker images from ECR
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # Must be in a public subnet
  depends_on    = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat"
  })
}

# ── Route tables ──────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-rt"
  })
}

# ── Route table associations ──────────────────────────────────────────────────
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}