variable "aws_region" {
  description = "AWS region for push infrastructure."
  type        = string
  default     = "ap-southeast-1"
}

variable "name_prefix" {
  description = "Prefix for named resources."
  type        = string
  default     = "push-dev"
}

variable "eks_cluster_name" {
  description = "Tên cluster EKS đã tồn tại; module chỉ tra cứu cluster này, không tạo cluster."
  type        = string
}

variable "firebase_service_account_json" {
  description = "Firebase service-account JSON content. Pass through TF_VAR_firebase_service_account_json or an approved secret retrieval workflow."
  type        = string
  sensitive   = true
}

variable "alert_topic_arn" {
  description = "Existing SNS alert topic ARN for CloudWatch alarms; empty disables alarm actions."
  type        = string
  default     = ""
}

variable "enable_reminder" {
  description = "Enable reminder SQS and EventBridge Scheduler resources."
  type        = bool
  default     = false
}

variable "enable_dlq_alarm" {
  description = "Alarm when the reminder DLQ contains visible messages."
  type        = bool
  default     = true
}

variable "identity_mode" {
  description = "Workload identity method: pod_identity (default) or irsa."
  type        = string
  default     = "pod_identity"
}

variable "eks_namespace" {
  description = "Namespace for notification-service service account."
  type        = string
  default     = "fcourt-dev"
}


variable "eks_service_account" {
  description = "Kubernetes service account for notification-service."
  type        = string
  default     = "notification-service"
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN, required for IRSA."
  type        = string
  default     = ""
}

variable "delivery_success_sample_rate" {
  description = "SNS successful delivery sample percentage for CloudWatch logs."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = { Environment = "dev", ManagedBy = "Terraform" }
}
