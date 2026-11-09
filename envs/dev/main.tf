module "push" {
  source = "../../modules/push"

  name_prefix                   = var.name_prefix
  eks_cluster_name              = var.eks_cluster_name
  firebase_service_account_json = var.firebase_service_account_json
  alert_topic_arn               = var.alert_topic_arn
  enable_reminder               = var.enable_reminder
  enable_dlq_alarm              = var.enable_dlq_alarm
  identity_mode                 = var.identity_mode
  eks_namespace                 = var.eks_namespace
  eks_service_account           = var.eks_service_account
  oidc_provider_arn             = var.oidc_provider_arn
  delivery_success_sample_rate  = var.delivery_success_sample_rate
  tags                          = var.tags
}

module "notification_service_pod_identity" {
  count  = var.identity_mode == "pod_identity" ? 1 : 0
  source = "../../modules/pod-identity"

  cluster_name         = var.eks_cluster_name
  namespace            = var.eks_namespace
  service_account_name = var.eks_service_account
  role_arn             = module.push.notification_service_role_arn
  tags                 = var.tags
}

module "ecr" {
  source = "../../modules/ecr"

  tags = var.tags
}
