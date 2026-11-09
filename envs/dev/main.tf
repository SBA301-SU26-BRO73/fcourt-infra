locals {
  env  = "dev"
  name = "fcourt-dev"
  tags = {
    Project = "fcourt", Env = "dev", ManagedBy = "terraform"
  }
}
module "network" {

  source                  = "../../modules/network"
  name                    = local.name
  env                     = local.env
  cluster_name            = local.name
  cidr                    = var.vpc_cidr
  single_nat_gateway      = true
  nodes_in_public_subnets = var.nodes_in_public_subnets
  enable_flow_logs        = var.enable_flow_logs
  enable_ecr_endpoints    = var.enable_interface_endpoints
  tags                    = local.tags

}
module "eks" {

  source                        = "../../modules/eks"
  cluster_name                  = local.name
  cluster_version               = var.cluster_version
  private_subnet_ids            = module.network.private_subnet_ids
  public_subnet_ids             = module.network.public_subnet_ids
  nodes_in_public_subnets       = var.nodes_in_public_subnets
  vpc_id                        = module.network.vpc_id
  instance_types                = var.eks_instance_types
  min_size                      = var.eks_min_size
  desired_size                  = var.eks_desired_size
  max_size                      = var.eks_max_size
  root_volume_size              = var.eks_root_volume_size
  capacity_type                 = var.eks_capacity_type
  cluster_log_types             = var.eks_cluster_log_types
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
  enable_secrets_encryption     = var.enable_secrets_encryption
  cluster_public_access_cidrs   = var.cluster_public_access_cidrs
  admin_principal_arns          = var.admin_principal_arns
  tags                          = local.tags

}
module "workload_identity" {

  source       = "../../modules/workload-identity"
  cluster_name = module.eks.cluster_name
  cluster_arn  = module.eks.cluster_arn
  env          = local.env
  tags         = local.tags

}
module "ecr" {

  source            = "../../modules/ecr"
  repository_prefix = "fcourt-dev"
  tags              = local.tags

}
module "push" {

  source                        = "../../modules/push"
  name_prefix                   = "fcourt-dev-push"
  eks_cluster_name              = module.eks.cluster_name
  firebase_service_account_json = var.firebase_service_account_json
  alert_topic_arn               = var.alert_topic_arn
  enable_reminder               = var.enable_reminder
  enable_dlq_alarm              = true
  identity_mode                 = "pod_identity"
  eks_namespace                 = "fcourt-dev"
  eks_service_account           = "notification-service"
  oidc_provider_arn             = ""
  delivery_success_sample_rate  = 0
  tags                          = local.tags

}
module "notification_service_pod_identity" {

  source               = "../../modules/pod-identity"
  cluster_name         = module.eks.cluster_name
  namespace            = "fcourt-dev"
  service_account_name = "notification-service"
  role_arn             = module.push.notification_service_role_arn
  tags                 = local.tags

}
module "budget" {
  source        = "../../modules/budget"
  name          = "fcourt-dev-monthly"
  amount        = var.monthly_budget_usd
  email_address = var.budget_email
  tags          = local.tags
}
