# Step 1: Create the VPC with DNS support enabled so services inside it
# can resolve public and private hostnames.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = merge(var.common_tags, {
    Name = "ecs-vpc"
  })
}

# Step 2: Create public subnets across availability zones.
# These host the ALB and are reachable from the internet.

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.common_tags, {
    Name = each.key
  })
}

# Step 3: Create private subnets across availability zones.
# These host the ECS Fargate tasks and are not directly accessible from the internet.

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.common_tags, {
    Name = each.key
  })
}

# Step 4: Create an internet gateway and attach it to the VPC.
# This enables resources in public subnets to communicate with the internet.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "ecs-igw"
  })
}

# Step 5: Create a public route table with a default route through the internet gateway,
# then associate it with every public subnet so outbound traffic reaches the internet.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Step 6: Create a private route table with local-only routing (no internet route),
# then associate it with every private subnet to keep ECS tasks isolated.

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "private-rt"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Step 7: Create a security group for VPC Interface Endpoints.
# ECS tasks in private subnets connect to AWS services over HTTPS through these endpoints.

resource "aws_security_group" "vpc_endpoints" {
  vpc_id      = aws_vpc.main.id
  description = "Allow HTTPS from private subnets to VPC endpoints"

  ingress {
    description = "HTTPS from VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.common_tags, {
    Name = "vpc-endpoints-sg"
  })
}

# Step 8: Create VPC endpoints so ECS Fargate tasks in private subnets can
# pull images from ECR and send logs to CloudWatch without a NAT Gateway.

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  tags                = merge(var.common_tags, { Name = "ecr-api-endpoint" })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  tags                = merge(var.common_tags, { Name = "ecr-dkr-endpoint" })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = merge(var.common_tags, { Name = "s3-endpoint" })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  tags                = merge(var.common_tags, { Name = "logs-endpoint" })
}
