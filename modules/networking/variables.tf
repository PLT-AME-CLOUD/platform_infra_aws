variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  description = "Map of public subnets keyed by name, each with a CIDR and availability zone"
}

variable "private_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
  description = "Map of private subnets keyed by name, each with a CIDR and availability zone"
}

variable "common_tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources"
}
