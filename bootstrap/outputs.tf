output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions to assume"
  value       = aws_iam_role.github_actions.arn
}

output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = local.state_bucket_id
}
