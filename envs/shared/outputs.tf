output "ecr_registry_url" {
  description = "ECR registry hostname."
  value       = module.ecr.registry_url
}
output "ecr_repository_urls" {
  description = "Repository URL by service."
  value       = module.ecr.repository_urls
}
output "github_ecr_push_role_arn" {
  description = "Set as repository variable AWS_ECR_PUSH_ROLE_ARN in SBA301-SU26-BRO73/fcourt-backend."
  value       = aws_iam_role.github_ecr_push.arn
}
output "local_media_bucket_name" {
  description = "Bucket for docker-compose development (STORAGE_S3_BUCKET in fcourt-backend .env)."
  value       = module.local_media.bucket_name
}
output "local_media_public_base_url" {
  description = "Public base URL of the local bucket (STORAGE_PUBLIC_BASE_URL)."
  value       = module.local_media.public_base_url
}
output "local_s3_user_name" {
  description = "IAM user whose access key is created manually for docker-compose."
  value       = aws_iam_user.local_s3.name
}

output "web_zone_name_servers" {
  description = "Add these as NS records for the web subdomain at the parent domain's DNS provider."
  value       = aws_route53_zone.web.name_servers
}
output "web_bucket_name" {
  description = "Set as repository variable WEB_BUCKET in SBA301-SU26-BRO73/fcourt-web."
  value       = aws_s3_bucket.web.bucket
}
output "web_distribution_id" {
  description = "Set as repository variable WEB_DISTRIBUTION_ID in SBA301-SU26-BRO73/fcourt-web."
  value       = aws_cloudfront_distribution.web.id
}
output "web_distribution_domain_name" {
  description = "CloudFront domain name (target of the web domain alias)."
  value       = aws_cloudfront_distribution.web.domain_name
}
output "github_web_deploy_role_arn" {
  description = "Set as repository variable AWS_WEB_DEPLOY_ROLE_ARN in SBA301-SU26-BRO73/fcourt-web."
  value       = aws_iam_role.github_web_deploy.arn
}
output "web_zone_id" {
  description = "Hosted zone id of the web domain (used by scripts/update-origin-record.sh)."
  value       = aws_route53_zone.web.zone_id
}
output "web_api_origin_name" {
  description = "Stable DNS name that CloudFront uses as API origin; CNAME to the current ALB."
  value       = local.web_api_origin
}
