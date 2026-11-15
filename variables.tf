variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "public_subnet_1_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR for first public subnet"
}

variable "public_subnet_2_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "CIDR for second public subnet"
}

variable "private_subnet_1_cidr" {
  type        = string
  default     = "10.0.3.0/24"
  description = "CIDR for first private subnet"
}

variable "private_subnet_2_cidr" {
  type        = string
  default     = "10.0.4.0/24"
  description = "CIDR for second private subnet"
}
