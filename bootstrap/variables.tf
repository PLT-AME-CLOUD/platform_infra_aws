variable "github_org" {
  type        = string
  description = "GitHub organization or username that owns the repository"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without the org prefix)"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the S3 state bucket"
}

variable "state_bucket_name" {
  type        = string
  default     = "ecs-workshop-tfstate"
  description = "Name of the S3 bucket for Terraform state"
}

