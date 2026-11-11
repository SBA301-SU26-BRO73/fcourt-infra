# Long-lived media bucket for local docker-compose development (fcourt-backend). Separate from the EKS media bucket
# in envs/prod so the orphan-image cleanup job of one environment never deletes the other's objects, and so it
# survives scripts/down.sh.
module "local_media" {
  source               = "../../modules/media"
  bucket_name          = "fcourt-local-media-${data.aws_caller_identity.current.account_id}"
  create_service_roles = false # no Pod Identity roles: compose uses the IAM user below
  force_destroy        = false
  tags                 = local.tags
}

resource "aws_iam_user" "local_s3" {
  name = "fcourt-local-s3"
  tags = local.tags
}

# No access key here on purpose: a key created by Terraform would store its secret in state.
# Create it by hand, see README ("Local media bucket").
resource "aws_iam_user_policy" "local_s3" {
  name = "fcourt-local-media-access"
  user = aws_iam_user.local_s3.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ObjectsInLocalBucket"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${module.local_media.bucket_arn}/*"
      },
      {
        Sid      = "ListLocalBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = module.local_media.bucket_arn
      }
    ]
  })
}
