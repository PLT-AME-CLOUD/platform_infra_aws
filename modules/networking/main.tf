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
