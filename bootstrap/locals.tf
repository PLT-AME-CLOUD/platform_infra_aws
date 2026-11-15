locals {
  state_bucket_arn    = aws_s3_bucket.tfstate.arn
  state_bucket_id     = aws_s3_bucket.tfstate.id
  oidc_provider_arn   = aws_iam_openid_connect_provider.github.arn
  github_actions_subs = [for repo in var.github_repos : "repo:${var.github_org}/${repo}:*"]
}
