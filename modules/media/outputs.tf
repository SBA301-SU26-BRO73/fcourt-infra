output "bucket_name" {
  description = "Media bucket name (STORAGE_S3_BUCKET)."
  value       = aws_s3_bucket.media.id
}

output "bucket_arn" {
  description = "Media bucket ARN."
  value       = aws_s3_bucket.media.arn
}

output "region" {
  description = "Bucket region (STORAGE_S3_REGION)."
  value       = aws_s3_bucket.media.region
}

output "public_base_url" {
  description = "Regional virtual-hosted URL used as STORAGE_PUBLIC_BASE_URL (no trailing slash)."
  value       = "https://${aws_s3_bucket.media.bucket_regional_domain_name}"
}

output "service_role_arns" {
  description = "Pod Identity role ARN by service account name (auth-service, facility-service, discovery-service, payment-service, booking-service)."
  value       = { for k, r in aws_iam_role.service : k => r.arn }
}
