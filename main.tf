provider "aws" {
  version = "~> 2.7"
  region  = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "example" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "vpc-${var.project_tag}"
    Project = var.project_tag
  }
}

resource "aws_subnet" "public" {
  count = var.public_subnet_count

  vpc_id     = aws_vpc.example.id
  cidr_block = var.subnet_cidr_blocks[count.index * 2]

  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available)]

  tags = {
    Name    = "public-${var.project_tag}-${format("%03d", count.index + 1)}"
    Project = var.project_tag
  }
}

resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id     = aws_vpc.example.id
  cidr_block = var.subnet_cidr_blocks[(count.index * 2) + 1]

  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available)]

  tags = {
    Name    = "private-${var.project_tag}-${format("%03d", count.index + 1)}"
    Project = var.project_tag
  }
}

resource "aws_internet_gateway" "vpc" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "igw-${var.project_tag}"
    Project = var.project_tag
  }
}

resource "aws_eip" "nat_gw" {
  vpc = true

  depends_on = [aws_internet_gateway.vpc]

  tags = {
    Name = "eip-${var.project_tag}"
    Project = var.project_tag
  }
}

resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.nat_gw.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.vpc]

  tags = {
    Name = "natgw-${var.project_tag}"
    Project = var.project_tag
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc.id
  }

  tags = {
    Name = "public-rout-table-${var.project_tag}"
    Project = var.project_tag
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public.id
  }

  tags = {
    Name = "private-rout-table-${var.project_tag}"
    Project = var.project_tag
  }
}

resource "aws_route_table_association" "public" {
  count = var.public_subnet_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id

}

resource "aws_route_table_association" "private" {
  count = var.private_subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id

}

# Security group

resource "aws_security_group" "public" {
  description = "Allow inbound HTTP/HTTPS traffic"
  vpc_id      = aws_vpc.example.id

  ingress {
    description = "HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP ingress"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg-${var.project_tag}"
    Project = var.project_tag
  }
}

resource "aws_security_group" "private" {
  description = "Allow inbound HTTP/HTTPS traffic from public subnet"
  vpc_id      = aws_vpc.example.id

  ingress {
    description = "HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = aws_subnet.public.*.cidr_block
  }

  ingress {
    description = "HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_subnet.public.*.cidr_block
  }

  ingress {
    description = "ICMP ingress"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = aws_subnet.public.*.cidr_block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg-${var.project_tag}"
    Project = var.project_tag
  }
}
