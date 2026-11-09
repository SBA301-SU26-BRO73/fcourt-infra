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
output "rds_endpoint" {
  description = "PostgreSQL host:port."
  value       = "${module.rds.address}:${module.rds.port}"
}
output "rds_database" {
  description = "Initial PostgreSQL database."
  value       = module.rds.database
}
output "rds_master_secret_arn" {
  description = "Managed master secret ARN."
  value       = module.rds.master_secret_arn
}
output "msk_bootstrap_brokers" {
  description = "MSK Serverless TLS/IAM broker list."
  value       = module.msk.bootstrap_brokers_sasl_iam
}
output "redis_endpoint" {
  description = "Private Redis host:port."
  value       = "${module.redis.primary_endpoint_address}:${module.redis.port}"
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
  value       = module.pod_identity.load_balancer_controller_role_arn
}
output "external_secrets_role_arn" {
  description = "External Secrets Operator role."
  value       = module.pod_identity.external_secrets_role_arn
}
output "ebs_csi_role_arn" {
  description = "EBS CSI Pod Identity role."
  value       = module.eks.ebs_csi_role_arn
}
