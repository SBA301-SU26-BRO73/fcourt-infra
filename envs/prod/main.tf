locals {
  env  = "prod"
  name = "fcourt-prod"
  tags = {
    Project = "fcourt", Env = "prod", ManagedBy = "terraform"
  }
}
module "network" {

  source               = "../../modules/network"
  name                 = local.name
  env                  = local.env
  cluster_name         = local.name
  cidr                 = var.vpc_cidr
  single_nat_gateway   = false
  enable_flow_logs     = var.enable_flow_logs
  enable_ecr_endpoints = var.enable_ecr_endpoints
  tags                 = local.tags

}
module "eks" {

  source                      = "../../modules/eks"
  cluster_name                = local.name
  cluster_version             = var.cluster_version
  private_subnet_ids          = module.network.private_subnet_ids
  vpc_id                      = module.network.vpc_id
  instance_types              = var.eks_instance_types
  min_size                    = var.eks_min_size
  desired_size                = var.eks_desired_size
  max_size                    = var.eks_max_size
  root_volume_size            = 50
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  admin_principal_arns        = var.admin_principal_arns
  tags                        = local.tags

}
module "workload_identity" {

  source       = "../../modules/workload-identity"
  cluster_name = module.eks.cluster_name
  cluster_arn  = module.eks.cluster_arn
  env          = local.env
  tags         = local.tags

}
module "rds" {

  source                 = "../../modules/rds"
  name                   = "fcourt-prod-postgres"
  env                    = local.env
  subnet_ids             = module.network.private_subnet_ids
  vpc_id                 = module.network.vpc_id
  node_security_group_id = module.eks.node_security_group_id
  instance_class         = "db.t4g.medium"
  allocated_storage      = 100
  multi_az               = true
  tags                   = local.tags

}
module "msk" {

  source                 = "../../modules/msk"
  name                   = "fcourt-prod-kafka"
  subnet_ids             = slice(module.network.private_subnet_ids, 0, 2)
  vpc_id                 = module.network.vpc_id
  node_security_group_id = module.eks.node_security_group_id
  tags                   = local.tags

}
module "redis" {

  source                 = "../../modules/redis"
  name                   = "fcourt-prod-redis"
  subnet_ids             = module.network.private_subnet_ids
  vpc_id                 = module.network.vpc_id
  node_security_group_id = module.eks.node_security_group_id
  node_type              = "cache.t4g.small"
  multi_az               = true
  tags                   = local.tags

}
module "ecr" {

  source            = "../../modules/ecr"
  repository_prefix = "fcourt-prod"
  tags              = local.tags

}
module "push" {

  source                        = "../../modules/push"
  name_prefix                   = "fcourt-prod-push"
  eks_cluster_name              = module.eks.cluster_name
  firebase_service_account_json = var.firebase_service_account_json
  alert_topic_arn               = var.alert_topic_arn
  enable_reminder               = var.enable_reminder
  enable_dlq_alarm              = true
  identity_mode                 = "pod_identity"
  eks_namespace                 = "fcourt-prod"
  eks_service_account           = "notification-service"
  oidc_provider_arn             = ""
  delivery_success_sample_rate  = 0
  tags                          = local.tags

}
module "notification_service_pod_identity" {

  source               = "../../modules/pod-identity"
  cluster_name         = module.eks.cluster_name
  namespace            = "fcourt-prod"
  service_account_name = "notification-service"
  role_arn             = module.push.notification_service_role_arn
  tags                 = local.tags

}
