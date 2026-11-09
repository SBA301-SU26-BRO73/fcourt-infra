output "repository_urls" {
  description = "Map of service names to ECR repository URLs."
  value = {
    for service, repository in aws_ecr_repository.service : service => repository.repository_url
  }
}

output "registry_url" {
  description = "Account ECR registry hostname shared by this environment's repositories."
  value       = split("/", aws_ecr_repository.service[sort(var.services)[0]].repository_url)[0]
}

output "repository_arns" {
  description = "Map of service names to ECR repository ARNs."
  value = {
    for service, repository in aws_ecr_repository.service : service => repository.arn
  }
}
