output "repository_urls" {
  description = "Map of service names to ECR repository URLs."
  value       = { for service, repository in aws_ecr_repository.service : service => repository.repository_url }
}

output "repository_arns" {
  description = "Map of service names to ECR repository ARNs."
  value       = { for service, repository in aws_ecr_repository.service : service => repository.arn }
}
