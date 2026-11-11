# Long-lived resources shared by every environment: ECR repositories and the GitHub Actions push role.
# Never destroyed by scripts/down.sh. Destroying this root deletes every image.
locals {
  env  = "shared"
  name = "fcourt-shared"

  tags = {
    Project   = "fcourt"
    Env       = local.env
    ManagedBy = "terraform"
  }

  github_oidc_url = "token.actions.githubusercontent.com"

  # GitHub now issues immutable subjects (repo:<owner>@<owner_id>/<repo>@<repo_id>:...); accept both forms.
  github_sub_prefixes = compact(["repo:${var.github_repository}", var.github_immutable_sub_prefix])
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

module "ecr" {
  source                        = "../../modules/ecr"
  repository_prefix             = "fcourt"
  image_tag_mutability          = "MUTABLE" # CI moves :latest on every push
  tagged_image_count            = var.tagged_image_count
  untagged_image_retention_days = var.untagged_image_retention_days
  tags                          = local.tags
}

module "budget" {
  source        = "../../modules/budget"
  name          = "${local.name}-monthly"
  amount        = var.monthly_budget_usd
  email_address = var.budget_email
  tags          = local.tags
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://${local.github_oidc_url}"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub's certificate chain itself; the thumbprint is required by the API but ignored.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = local.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://${local.github_oidc_url}"
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_ecr_push" {
  name        = "${local.name}-github-ecr-push"
  description = "Assumed by GitHub Actions in ${var.github_repository} to push images to fcourt/* ECR repositories."
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.github_oidc_url}:aud" = "sts.amazonaws.com"
          "${local.github_oidc_url}:sub" = flatten([for prefix in local.github_sub_prefixes : [for ref in var.github_refs : "${prefix}:ref:refs/heads/${ref}"]])
        }
      }
    }]
  })
  max_session_duration = 3600
  tags                 = local.tags
}

resource "aws_iam_role_policy" "github_ecr_push" {
  name = "ecr-push-fcourt"
  role = aws_iam_role.github_ecr_push.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PushToFcourtRepositories"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = values(module.ecr.repository_arns)
      }
    ]
  })
}
