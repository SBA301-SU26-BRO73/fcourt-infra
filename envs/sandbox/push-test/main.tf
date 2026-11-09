locals {
  tags = {
    Project   = "fcourt"
    Env       = "push-test"
    ManagedBy = "terraform"
  }
}

module "push" {
  source                        = "../../../modules/push"
  name_prefix                   = "fcourt-test-push"
  create_workload_role          = false
  enable_delivery_logging       = false
  firebase_service_account_json = var.firebase_service_account_json
  enable_reminder               = false
  enable_dlq_alarm              = false
  alert_topic_arn               = ""
  tags                          = local.tags
}
