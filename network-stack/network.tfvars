vpc_cidr = "10.0.0.0/16"

public_subnets = {
  "public-subnet-1" = { cidr = "10.0.1.0/24" }
  "public-subnet-2" = { cidr = "10.0.2.0/24" }
}

private_subnets = {
  "private-subnet-1" = { cidr = "10.0.3.0/24" }
  "private-subnet-2" = { cidr = "10.0.4.0/24" }
}
