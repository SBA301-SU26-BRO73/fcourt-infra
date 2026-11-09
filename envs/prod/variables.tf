variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}
variable "vpc_cidr" {
  description = "Production VPC CIDR; must not overlap connected networks."
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
  default = "10.50.0.0/16"
}
variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.34"
}
variable "eks_instance_types" {
  description = "Production worker EC2 instance types."
  type        = list(string)
  default     = ["m7i.large"]
}
variable "eks_min_size" {
  description = "Minimum EKS worker count for production."
  type        = number
  default     = 3
}
variable "eks_desired_size" {
  description = "Desired EKS worker count for production."
  type        = number
  default     = 3
}
variable "eks_max_size" {
  description = "Maximum EKS worker count for production."
  type        = number
  default     = 9
}
variable "cluster_public_access_cidrs" {
  description = "Allowed trusted public client CIDRs for the Kubernetes API."
  type        = list(string)
  validation {
    condition     = !contains(var.cluster_public_access_cidrs, "0.0.0.0/0")
    error_message = "Do not expose the Kubernetes API to 0.0.0.0/0; list trusted client CIDRs."
  }
}
variable "admin_principal_arns" {
  description = "IAM user/role ARNs granted cluster-admin access. Required; keep tightly scoped."
  type        = list(string)
  validation {
    condition     = length(var.admin_principal_arns) > 0
    error_message = "At least one admin principal ARN is required."
  }
}
variable "firebase_service_account_json" {
  description = "Sensitive Firebase service-account JSON passed from an approved secret store; never commit it."
  type        = string
  sensitive   = true
}
variable "alert_topic_arn" {
  description = "Optional existing SNS topic ARN for alarms."
  type        = string
  default     = ""
}
variable "enable_reminder" {
  description = "Enable notification reminder queues and schedules."
  type        = bool
  default     = false
}
variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs; adds CloudWatch ingestion and storage cost."
  type        = bool
  default     = true
}
variable "enable_ecr_endpoints" {
  description = "Enable paid ECR interface endpoints for private image pulls."
  type        = bool
  default     = false
}
