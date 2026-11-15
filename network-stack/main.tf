# Step 1: Call the networking child module to create VPC, subnets, internet gateway,
# and route tables. Subnet CIDRs come from network.tfvars, AZs are computed in locals,
# and all resources receive the common project tags.

module "networking" {
  source = "../modules/networking"

  vpc_cidr        = var.vpc_cidr
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets
  common_tags     = local.common_tags
}
