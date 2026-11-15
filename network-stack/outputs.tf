output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Map of public subnet names to their IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Map of private subnet names to their IDs"
  value       = module.networking.private_subnet_ids
}
