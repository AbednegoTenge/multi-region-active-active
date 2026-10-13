

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.region

  # ChaosTarget marks resources AWS FIS may break; Layer lets an experiment pick app, data or network.
  chaos_tags   = { ChaosTarget = "true", Region = local.region }
  network_tags = merge(local.chaos_tags, { Layer = "network" })
  app_tags     = merge(local.chaos_tags, { Layer = "app" })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = merge(local.network_tags, {
    Name = "${local.region}-vpc"
  })

}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = merge(local.network_tags, {
    Name = "${local.region}-igw"
  })
}


resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.network_tags, { Name = "${local.region}-rt" })
}

resource "aws_subnet" "subnet" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.network_tags, {
    Name = "${local.region}-subnet-${count.index}"
  })
}


resource "aws_route_table_association" "rt_association" {
  count          = 2
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.rt.id
}


resource "aws_security_group" "lb_sg" {
  name_prefix        = "${local.region}-lb-sg"
  description = "Security group for load balancer in ${local.region}"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.network_tags, { Name = "${local.region}-lb-sg" })
}
