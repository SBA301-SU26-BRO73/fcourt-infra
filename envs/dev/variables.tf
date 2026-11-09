variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}
variable "vpc_cidr" {
  description = "VPC CIDR; must not overlap connected networks."
  type        = string
  default     = "10.40.0.0/16"
}
variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.34"
}
variable "eks_instance_types" {
  description = "Diversified 4-vCPU, 16-GiB EC2 Spot types for the demo node group."
  type        = list(string)
  default     = ["t3a.xlarge", "t3.xlarge", "m5a.xlarge", "m5.xlarge"]
}
variable "eks_capacity_type" {
  description = "Managed node group capacity type."
  type        = string
  default     = "SPOT"
}
variable "eks_root_volume_size" {
  description = "Worker gp3 root volume size in GiB."
  type        = number
  default     = 20
}
variable "eks_min_size" {
  description = "Minimum EKS worker count; keep at least one for dev."
  type        = number
  default     = 1
  validation {
    condition     = var.eks_min_size >= 1
    error_message = "At least one EKS worker is required."
  }
}
variable "eks_desired_size" {
  description = "Desired EKS worker count for dev."
  type        = number
  default     = 1
}
variable "eks_max_size" {
  description = "Maximum EKS worker count for dev."
  type        = number
  default     = 2
}
variable "cluster_public_access_cidrs" {
  description = "Allowed public Kubernetes API client CIDRs. Replace the example with trusted IP ranges."
  type        = list(string)
}
variable "admin_principal_arns" {
  description = "IAM user/role ARNs granted cluster-admin access. Required; keep tightly scoped."
  type        = list(string)
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
