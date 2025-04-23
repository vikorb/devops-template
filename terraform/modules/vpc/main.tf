/**
 * Module VPC
 * Ce module crée un VPC avec des sous-réseaux publics et privés répartis sur plusieurs AZ
 */

# Définition du VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name = "${var.environment}-vpc"
    },
    var.tags
  )
}

# Internet Gateway pour permettre l'accès internet depuis les sous-réseaux publics
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.environment}-igw"
    },
    var.tags
  )
}

# Création des sous-réseaux publics dans chaque AZ spécifiée
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${var.environment}-public-subnet-${count.index + 1}"
      Type = "Public"
    },
    var.tags
  )
}

# Création des sous-réseaux privés dans chaque AZ spécifiée
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name = "${var.environment}-private-subnet-${count.index + 1}"
      Type = "Private"
    },
    var.tags
  )
}

# Allocation d'adresses IP élastiques pour les NAT Gateways
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? length(var.availability_zones) : 0
  domain = "vpc"

  tags = merge(
    {
      Name = "${var.environment}-nat-eip-${count.index + 1}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways pour permettre l'accès internet depuis les sous-réseaux privés
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? length(var.availability_zones) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    {
      Name = "${var.environment}-nat-gateway-${count.index + 1}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

# Table de routage pour les sous-réseaux publics
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    {
      Name = "${var.environment}-public-route-table"
    },
    var.tags
  )
}

# Association des sous-réseaux publics avec leur table de routage
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Tables de routage pour les sous-réseaux privés
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.environment}-private-route-table-${count.index + 1}"
    },
    var.tags
  )
}

# Routes vers les NAT Gateways pour les sous-réseaux privés
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? length(var.availability_zones) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Association des sous-réseaux privés avec leurs tables de routage
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Groupe de sécurité par défaut
resource "aws_security_group" "default" {
  name        = "${var.environment}-default-sg"
  description = "Default security group for VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.environment}-default-sg"
    },
    var.tags
  )
}