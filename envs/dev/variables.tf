variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}
variable "vpc_cidr" {
  description = "VPC CIDR; must not overlap connected networks."
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
  default = "10.40.0.0/16"
}
variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.35"
}
variable "eks_instance_types" {
  description = "Diversified 2-vCPU, 8-GiB EC2 types for the demo node group (Spot pool diversification)."
  type        = list(string)
  default     = ["t3.large", "t3a.large", "m6i.large"]
}
variable "eks_capacity_type" {
  description = "Managed node group capacity type."
  type        = string
  default     = "SPOT"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.eks_capacity_type)
    error_message = "eks_capacity_type must be ON_DEMAND or SPOT."
  }
}
variable "eks_root_volume_size" {
  description = "Worker gp3 root volume size in GiB."
  type        = number
  default     = 20
}
variable "eks_min_size" {
  description = "Minimum EKS worker count; dev needs 2 for the 12 services plus data."
  type        = number
  default     = 2
  validation {
    condition     = var.eks_min_size >= 1
    error_message = "At least one EKS worker is required."
  }
}
variable "eks_desired_size" {
  description = "Desired EKS worker count for dev."
  type        = number
  default     = 2
  validation {
    condition     = var.eks_desired_size >= var.eks_min_size && var.eks_desired_size <= var.eks_max_size
    error_message = "eks_desired_size must be between eks_min_size and eks_max_size."
  }
}
variable "eks_max_size" {
  description = "Maximum EKS worker count for dev."
  type        = number
  default     = 2
}
variable "cluster_public_access_cidrs" {
  description = "Allowed public Kubernetes API client CIDRs. Replace the example with trusted IP ranges."
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
  default     = false
}
variable "enable_interface_endpoints" {
  description = "Enable paid VPC interface endpoints. S3 gateway endpoint is always present."
  type        = bool
  default     = false
}
variable "nodes_in_public_subnets" {
  description = "Place nodes in public subnets with public IPs and skip NAT for the cheapest demo."
  type        = bool
  default     = false
}
variable "eks_cluster_log_types" {
  description = "EKS control-plane log types; empty disables control-plane logging."
  type        = list(string)
  default     = []
}
variable "cloudwatch_log_retention_days" {
  description = "CloudWatch retention in days for EKS control-plane logs."
  type        = number
  default     = 3
}
variable "enable_secrets_encryption" {
  description = "Encrypt Kubernetes secrets with a customer-managed KMS key."
  type        = bool
  default     = false
}
variable "monthly_budget_usd" {
  description = "Monthly AWS cost budget in USD for dev."
  type        = number
  default     = 20
}
variable "budget_email" {
  description = "Email address for AWS Budget alerts."
  type        = string
}
