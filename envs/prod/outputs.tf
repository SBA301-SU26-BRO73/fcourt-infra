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
output "notification_service_role_arn" {
  description = "Notification-service Pod Identity role."
  value       = module.push.notification_service_role_arn
}
output "load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller role."
  value       = module.pod_identity.load_balancer_controller_role_arn
}
output "ebs_csi_role_arn" {
  description = "EBS CSI Pod Identity role."
  value       = module.eks.ebs_csi_role_arn
}
# ECR lives in envs/shared (long-lived). These are derived, not read from that state,
# so this root applies on an empty account even before envs/shared exists.
data "aws_caller_identity" "current" {}

output "ecr_registry_url" {
  description = "ECR registry hostname (repos fcourt/<service> are owned by envs/shared)."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}
output "ecr_repository_prefix" {
  description = "Repository prefix used by envs/shared: <registry>/fcourt/<service>."
  value       = "fcourt"
}
output "push_platform_application_arn" {
  description = "SNS platform application ARN for PUSH_SNS_PLATFORM_APPLICATION_ARN (fcourt-gitops scripts/apply-terraform-outputs.sh)."
  value       = module.push.platform_application_arn
}
output "media_bucket_name" {
  description = "Media bucket for STORAGE_S3_BUCKET (fcourt-gitops scripts/apply-terraform-outputs.sh)."
  value       = module.media.bucket_name
}
output "media_public_base_url" {
  description = "Regional virtual-hosted bucket URL for STORAGE_PUBLIC_BASE_URL."
  value       = module.media.public_base_url
}
output "media_service_role_arns" {
  description = "Per-service S3 Pod Identity roles (auth, facility, discovery, payment, booking)."
  value       = module.media.service_role_arns
}
output "gitops_values" {
  description = "Values consumed by fcourt-gitops (scripts/apply-terraform-outputs.sh)."
  value = {
    region                        = var.aws_region
    cluster_name                  = module.eks.cluster_name
    namespace                     = local.namespace
    vpc_id                        = module.network.vpc_id
    push_platform_application_arn = module.push.platform_application_arn
    media_bucket_name             = module.media.bucket_name
    media_public_base_url         = module.media.public_base_url
  }
}
