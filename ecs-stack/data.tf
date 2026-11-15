# Read outputs from the network stack's remote state so this stack
# can place ALB and ECS tasks in the correct VPC and subnets.

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "ecs-workshop-tfstate"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
