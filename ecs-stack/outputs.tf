output "alb_dns_name" {
  description = "DNS name of the public ALB"
  value       = module.ecs.alb_dns_name
}

output "internal_alb_dns_name" {
  description = "DNS name of the internal ALB (frontend → backend)"
  value       = module.ecs.internal_alb_dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecs.ecr_repository_url
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}
