variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}

variable "name_prefix" {
  description = "Unique prefix for production resources."
  type        = string
  default     = "push-prod"
}

variable "eks_cluster_name" {
  description = "Name of the existing EKS cluster; this configuration only looks it up."
  type        = string
}

variable "firebase_service_account_json" {
  description = "Firebase service-account JSON content; pass securely through TF_VAR_firebase_service_account_json."
  type        = string
  sensitive   = true
}

variable "alert_topic_arn" {
  description = "Existing SNS topic ARN for alarm actions; empty disables actions."
  type        = string
  default     = ""
}

variable "enable_reminder" {
  description = "Enable reminder SQS queues and EventBridge Scheduler resources."
  type        = bool
  default     = false
}

variable "enable_dlq_alarm" {
  description = "Create the reminder DLQ alarm."
  type        = bool
  default     = true
}

variable "identity_mode" {
  description = "Workload identity: EKS Pod Identity (default) or IRSA."
  type        = string
  default     = "pod_identity"
  validation {
    condition     = contains(["pod_identity", "irsa"], var.identity_mode)
    error_message = "identity_mode must be pod_identity or irsa."
  }
}

variable "eks_namespace" {
  description = "Namespace for notification-service."
  type        = string
  default     = "fcourt-prod"
}

variable "eks_service_account" {
  description = "Service account for notification-service."
  type        = string
  default     = "notification-service"
}

variable "oidc_provider_arn" {
  description = "Existing OIDC provider ARN; required only for IRSA."
  type        = string
  default     = ""
}

variable "delivery_success_sample_rate" {
  description = "SNS successful delivery log sample percentage, from 0 to 100."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Default tags for production resources."
  type        = map(string)
  default     = { Environment = "prod", ManagedBy = "Terraform" }
}
