variable "name_prefix" {

  description = "Prefix used for resource names."
  type        = string
  default     = "push"

}

variable "eks_cluster_name" {

  description = "Name of an existing EKS cluster used to scope the workload role trust policy; required only when create_workload_role is true."
  type        = string
  default     = ""

}

variable "create_workload_role" {

  description = "Create the IAM role and policies that notification-service pods assume through Pod Identity or IRSA."
  type        = bool
  default     = true

}

variable "firebase_service_account_json" {

  description = "Firebase service-account JSON content used by SNS FCM HTTP v1. Supply securely, for example with TF_VAR_firebase_service_account_json."
  type        = string
  sensitive   = true

}

variable "alert_topic_arn" {

  description = "SNS topic ARN for alarms. Leave empty to create alarms without notification actions."
  type        = string
  default     = ""

}

variable "enable_reminder" {

  description = "Create reminder SQS queues and EventBridge Scheduler resources and grant reminder permissions."
  type        = bool
  default     = false

}

variable "enable_dlq_alarm" {

  description = "Create an alarm for visible messages in the reminder dead-letter queue."
  type        = bool
  default     = true

}

variable "identity_mode" {

  description = "How the notification-service pod receives AWS credentials: EKS Pod Identity (default) or IRSA."
  type        = string
  default     = "pod_identity"
  validation {

    condition     = contains(["pod_identity", "irsa"], var.identity_mode)
    error_message = "identity_mode must be pod_identity or irsa."

  }

}

variable "eks_namespace" {

  description = "Kubernetes namespace containing notification-service."
  type        = string
  default     = "fcourt-dev"

}

variable "eks_service_account" {

  description = "Kubernetes service account used by notification-service."
  type        = string
  default     = "notification-service"

}

variable "oidc_provider_arn" {

  description = "EKS OIDC provider ARN   required when identity_mode is irsa."
  type        = string
  default     = ""

}

variable "enable_delivery_logging" {

  description = "Create the SNS delivery status logging role and attach it to the platform application. Needs iam:PassRole for the caller."
  type        = bool
  default     = true

}

variable "delivery_success_sample_rate" {

  description = "Percentage of successful deliveries SNS should log (0-100)."
  type        = number
  default     = 0
  validation {

    condition     = var.delivery_success_sample_rate >= 0 && var.delivery_success_sample_rate <= 100
    error_message = "delivery_success_sample_rate must be between 0 and 100."

  }

}

variable "publish_failure_threshold" {

  description = "Failed SNS notifications per evaluation period that trigger the alarm."
  type        = number
  default     = 1

}

variable "dlq_visible_messages_threshold" {

  description = "Visible DLQ messages that trigger the reminder DLQ alarm."
  type        = number
  default     = 1

}

variable "tags" {

  description = "Tags applied to supported resources."
  type        = map(string)
  default = {

  }

}
