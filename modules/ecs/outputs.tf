output "alb_dns_name" {
  description = "DNS name of the public ALB"
  value       = aws_lb.main.dns_name
}

output "internal_alb_dns_name" {
  description = "DNS name of the internal ALB (frontend → backend)"
  value       = aws_lb.internal.dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}
