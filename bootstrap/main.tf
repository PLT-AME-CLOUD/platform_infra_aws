# Step 1: Create S3 bucket to store Terraform remote state files
resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name
}

# Step 2: Enable KMS server-side encryption on the state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = local.state_bucket_id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Step 3: Block all public access to the state bucket
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = local.state_bucket_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Step 4: Register GitHub as an OIDC identity provider so Actions can authenticate without long-lived credentials
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

# Step 5: Define a trust policy that allows GitHub Actions to assume a role via OIDC federation
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_actions_sub]
    }
  }
}

# Step 6: Create the IAM role that GitHub Actions workflows will assume
resource "aws_iam_role" "github_actions" {
  name               = "github-actions-ecs-workshop"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Step 7: Define the permissions the role needs — S3 state access,
# EC2 networking, and ECS application stack management
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid = "TerraformState"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      local.state_bucket_arn,
      "${local.state_bucket_arn}/*",
    ]
  }

  statement {
    sid = "NetworkInfra"
    actions = [
      "ec2:*Vpc*",
      "ec2:*Subnet*",
      "ec2:*InternetGateway*",
      "ec2:*RouteTable*",
      "ec2:*Route",
      "ec2:*Address*",
      "ec2:*Tags*",
      "ec2:Describe*",
      "ec2:*SecurityGroup*",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ACM"
    actions = [
      "acm:RequestCertificate",
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:DeleteCertificate",
      "acm:ListTagsForCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
    ]
    resources = ["*"]
  }

  statement {
    sid = "Route53"
    actions = [
      "route53:GetHostedZone",
      "route53:ChangeResourceRecordSets",
      "route53:GetChange",
      "route53:ListResourceRecordSets",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ECS"
    actions = [
      "ecs:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ECR"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:PutImageScanningConfiguration",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ELB"
    actions = [
      "elasticloadbalancing:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "IAM"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatch"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:ListTagsForResource",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ServiceDiscovery"
    actions = [
      "servicediscovery:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AutoScaling"
    actions = [
      "application-autoscaling:*",
    ]
    resources = ["*"]
  }
}

# Step 8: Attach the permissions policy to the GitHub Actions role
resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-ecs-workshop"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
