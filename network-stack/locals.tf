locals {
  common_tags = {
    Project   = "webapplication"
    ManagedBy = "terraform"
  }

  azs = data.aws_availability_zones.available.names

  public_subnets = {
    for name, subnet in var.public_subnets :
    name => { cidr = subnet.cidr, az = local.azs[index(keys(var.public_subnets), name)] }
  }

  private_subnets = {
    for name, subnet in var.private_subnets :
    name => { cidr = subnet.cidr, az = local.azs[index(keys(var.private_subnets), name)] }
  }
}
