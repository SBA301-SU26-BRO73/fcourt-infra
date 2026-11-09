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
