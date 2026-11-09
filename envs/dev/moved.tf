# State-preserving renames from the previous layout.
moved {
  from = module.workload_identity
  to   = module.pod_identity
}

moved {
  from = module.notification_service_pod_identity.aws_eks_pod_identity_association.service_account
  to   = module.pod_identity.aws_eks_pod_identity_association.extra["notification-service"]
}
