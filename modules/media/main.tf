# Per-environment media bucket for avatars, branch images, review images and sensitive documents
# (see fcourt-backend docs/storage-s3.md). Public read is limited to var.public_prefixes by bucket policy;
# owner-documents/, receipts/ and refund-proofs/ are served only through presigned URLs.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}"

  # Least-privilege table from docs/storage-s3.md section 6.4. Key = Kubernetes service account (= service name).
  service_policies = {
    auth-service = [
      {
        Sid      = "ObjectsAvatarsAndOwnerDocuments"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
        Resource = ["${local.bucket_arn}/avatars/*", "${local.bucket_arn}/owner-documents/*"]
      }
    ]
    facility-service = [
      {
        Sid      = "ObjectsBranches"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = ["${local.bucket_arn}/branches/*"]
      }
    ]
    discovery-service = [
      {
        Sid      = "ObjectsReviews"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = ["${local.bucket_arn}/reviews/*"]
      },
      {
        Sid       = "ListReviewsPrefix"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = local.bucket_arn
        Condition = { StringLike = { "s3:prefix" = ["reviews/*"] } }
      }
    ]
    payment-service = [
      {
        Sid      = "ObjectsReceiptsAndRefundProofs"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
        Resource = ["${local.bucket_arn}/receipts/*", "${local.bucket_arn}/refund-proofs/*"]
      }
    ]
    booking-service = [
      {
        Sid      = "ReadReceipts"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = ["${local.bucket_arn}/receipts/*"]
      }
    ]
  }
}

resource "aws_s3_bucket" "media" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_ownership_controls" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    object_ownership = "BucketOwnerEnforced" # ACLs disabled
  }
}

# ACL-based public access stays blocked. Only the policy-based switches are open so the prefix-scoped
# public-read statement below can take effect.
resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = toset(var.private_ia_prefixes)
    content {
      id     = "ia-${trimsuffix(rule.value, "/")}"
      status = "Enabled"
      filter {
        prefix = rule.value
      }
      transition {
        days          = 90
        storage_class = "STANDARD_IA"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "media" {
  bucket     = aws_s3_bucket.media.id
  depends_on = [aws_s3_bucket_public_access_block.media, aws_s3_bucket_ownership_controls.media]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [local.bucket_arn, "${local.bucket_arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "PublicReadImagePrefixes"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = [for p in var.public_prefixes : "${local.bucket_arn}/${p}*"]
      }
    ]
  })
}

# --- Per-service Pod Identity roles ------------------------------------------

resource "aws_iam_role" "service" {
  for_each = local.service_policies
  name     = "${var.role_name_prefix}-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnEquals    = { "aws:SourceArn" = var.cluster_arn }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "service" {
  for_each = local.service_policies
  name     = "${var.role_name_prefix}-${each.key}-s3"
  role     = aws_iam_role.service[each.key].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = each.value
  })
}
