# Step 1: Call the ECS child module to create the full application stack —
# ACM certificate, ECR repository, ECS cluster, ALB, services, auto-scaling,
# and service discovery. VPC and subnet IDs are read from the network stack's
# remote state so the two stacks stay loosely coupled.

module "ecs" {
  source = "../modules/ecs"

  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = values(data.terraform_remote_state.network.outputs.public_subnet_ids)
  private_subnet_ids = values(data.terraform_remote_state.network.outputs.private_subnet_ids)
  domain_name        = var.domain_name
  hosted_zone_id     = var.hosted_zone_id
  common_tags        = local.common_tags
}
