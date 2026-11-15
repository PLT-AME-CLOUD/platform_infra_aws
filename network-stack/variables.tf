variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnets" {
  type = map(object({
    cidr = string
  }))
  description = "Map of public subnets keyed by name, each with a CIDR block"
}

variable "private_subnets" {
  type = map(object({
    cidr = string
  }))
  description = "Map of private subnets keyed by name, each with a CIDR block"
}
