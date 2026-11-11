# fcourt-web delivery: private S3 bucket (OAC) + CloudFront + ACM (us-east-1) + Route 53 alias.
# The API is served through the same distribution (/api/*, /ws-fcourt*, /actuator/health -> EKS ALB), so the
# browser only ever talks to https://<web_domain> (no CORS). Cost: no WAF, no logging bucket, PriceClass_200.
locals {
  web_api_origin   = "${var.web_api_origin_label}.${var.web_domain}"
  web_sub_prefixes = compact(["repo:${var.web_github_repository}", var.web_github_immutable_sub_prefix])
}

# --- S3 -----------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "web" {
  bucket        = "fcourt-web-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # contents are a rebuildable build output
}

resource "aws_s3_bucket_public_access_block" "web" {
  bucket                  = aws_s3_bucket.web.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web" {
  bucket = aws_s3_bucket.web.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "web" {
  bucket = aws_s3_bucket.web.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudfront_origin_access_control" "web" {
  name                              = "${local.name}-web"
  description                       = "OAC for the fcourt-web bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontRead"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.web.arn}/*"
        Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.web.arn } }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.web.arn, "${aws_s3_bucket.web.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.web]
}

# --- ACM (us-east-1) validated through Route 53 -------------------------------------------------------------------
resource "aws_acm_certificate" "web" {
  provider          = aws.us_east_1
  domain_name       = var.web_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "web_cert_validation" {
  for_each = {
    for o in aws_acm_certificate.web.domain_validation_options : o.domain_name => {
      name   = o.resource_record_name
      type   = o.resource_record_type
      record = o.resource_record_value
    }
  }
  zone_id         = aws_route53_zone.web.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Waits until the registrar delegates the subdomain to the Route 53 name servers.
resource "aws_acm_certificate_validation" "web" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.web.arn
  validation_record_fqdns = [for r in aws_route53_record.web_cert_validation : r.fqdn]

  timeouts {
    create = "90m"
  }
}

# --- CloudFront ---------------------------------------------------------------------------------------------------
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# SPA fallback on the default (S3) behavior only. Custom error responses are avoided on purpose: they apply to the
# whole distribution and would turn API 404/403 responses into index.html.
resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${local.name}-web-spa-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite extension-less SPA routes to /index.html"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      var last = uri.substring(uri.lastIndexOf('/') + 1);
      if (last.indexOf('.') === -1) {
        request.uri = '/index.html';
      }
      return request;
    }
  JS
}

resource "aws_cloudfront_distribution" "web" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  comment             = "fcourt-web (${var.web_domain})"
  default_root_object = "index.html"
  aliases             = [var.web_domain]
  price_class         = "PriceClass_200" # includes Asia edges; PriceClass_100 has none

  origin {
    origin_id                = "web-s3"
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.web.id
  }

  origin {
    origin_id   = "api-alb"
    domain_name = local.web_api_origin
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
    }
  }

  default_cache_behavior {
    target_origin_id       = "web-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
  }

  dynamic "ordered_cache_behavior" {
    # Swagger UI and the aggregated OpenAPI docs are served by gateway-service.
    for_each = ["/api/*", "/ws-fcourt*", "/actuator/health", "/swagger-ui*", "/v3/api-docs*", "/docs/*"]
    content {
      path_pattern             = ordered_cache_behavior.value
      target_origin_id         = "api-alb"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = false
      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.web.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_route53_record" "web_a" {
  zone_id = aws_route53_zone.web.zone_id
  name    = var.web_domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.web.domain_name
    zone_id                = aws_cloudfront_distribution.web.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "web_aaaa" {
  zone_id = aws_route53_zone.web.zone_id
  name    = var.web_domain
  type    = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.web.domain_name
    zone_id                = aws_cloudfront_distribution.web.hosted_zone_id
    evaluate_target_health = false
  }
}

# --- GitHub Actions deploy role (fcourt-web) ----------------------------------------------------------------------
resource "aws_iam_role" "github_web_deploy" {
  name        = "${local.name}-github-web-deploy"
  description = "Assumed by GitHub Actions in ${var.web_github_repository} to sync the web build to S3 and invalidate CloudFront."
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.github_oidc_url}:aud" = "sts.amazonaws.com"
          "${local.github_oidc_url}:sub" = flatten([for prefix in local.web_sub_prefixes : [for ref in var.web_github_refs : "${prefix}:ref:refs/heads/${ref}"]])
        }
      }
    }]
  })
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "github_web_deploy" {
  name = "web-deploy"
  role = aws_iam_role.github_web_deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListWebBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.web.arn
      },
      {
        Sid      = "SyncWebObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.web.arn}/*"
      },
      {
        Sid      = "InvalidateWebDistribution"
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = aws_cloudfront_distribution.web.arn
      }
    ]
  })
}
