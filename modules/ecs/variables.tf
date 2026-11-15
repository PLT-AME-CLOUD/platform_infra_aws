variable "vpc_id" {
  type        = string
  description = "VPC ID for the ECS resources"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the ACM certificate (e.g. chakra86.store)"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for DNS validation of the ACM certificate"
}

variable "min_capacity" {
  type        = number
  default     = 0
  description = "Minimum number of tasks per service for auto-scaling"
}

variable "max_capacity" {
  type        = number
  default     = 4
  description = "Maximum number of tasks per service for auto-scaling"
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources"
}
