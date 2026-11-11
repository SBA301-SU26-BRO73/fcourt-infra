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
