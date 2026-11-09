output "region" {
  description = "AWS region."
  value       = var.aws_region
}
output "cluster_name" {
  description = "EKS cluster name for gitops."
  value       = module.eks.cluster_name
}
output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}
output "cluster_certificate_authority_data" {
  description = "EKS cluster CA bundle."
  value       = module.eks.cluster_certificate_authority_data
}
output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}
output "ecr_registry_urls" {
  description = "ECR repository URLs by service."
  value       = module.ecr.repository_urls
}
output "ecr_registry_url" {
  description = "ECR registry hostname for image push/pull login."
  value       = module.ecr.registry_url
}
output "notification_service_role_arn" {
  description = "Notification-service Pod Identity role."
  value       = module.push.notification_service_role_arn
}
output "load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller role."
  value       = module.workload_identity.load_balancer_controller_role_arn
}
output "external_secrets_role_arn" {
  description = "External Secrets Operator role."
  value       = module.workload_identity.external_secrets_role_arn
}
output "ebs_csi_role_arn" {
  description = "EBS CSI Pod Identity role."
  value       = module.eks.ebs_csi_role_arn
}
