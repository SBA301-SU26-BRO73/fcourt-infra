variable "cluster_name" {
  description = "Unique EKS cluster name."
  type        = string
}
variable "cluster_version" {
  description = "Kubernetes version supported by EKS in the target region."
  type        = string
  default     = "1.34"
}
variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS control plane and worker nodes."
  type        = list(string)
}
variable "public_subnet_ids" {
  description = "Public subnet IDs, used only when nodes_in_public_subnets is true."
  type        = list(string)
  default     = []
}
variable "node_subnet_count" {
  description = "Number of subnets (AZs) used by the node group, taken from the start of the chosen set. 1 keeps nodes and EBS volumes in one AZ."
  type        = number
  default     = 1
  validation {
    condition     = var.node_subnet_count >= 1 && var.node_subnet_count <= 3
    error_message = "node_subnet_count must be between 1 and 3."
  }
}
variable "nodes_in_public_subnets" {
  description = "Place nodes in public subnets and assign public IPs."
  type        = bool
  default     = false
}
variable "capacity_type" {
  description = "Managed node group capacity type, ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}
variable "vpc_id" {
  description = "VPC ID for EKS security groups."
  type        = string
}
variable "cluster_public_access_cidrs" {
  description = "CIDRs permitted to reach the public Kubernetes API endpoint."
  type        = list(string)
  validation {
    condition     = length(var.cluster_public_access_cidrs) > 0 && alltrue([for cidr in var.cluster_public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Provide valid trusted CIDRs; unrestricted public API access is not allowed."
  }
}
variable "root_volume_size" {
  description = "Encrypted gp3 worker root volume size in GiB."
  type        = number
  default     = 30
}
variable "instance_types" {
  description = "EC2 instance types used by the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}
variable "min_size" {
  description = "Minimum managed node group size."
  type        = number
  default     = 1
  validation {
    condition     = var.min_size >= 1
    error_message = "min_size must be at least 1."
  }
}
variable "desired_size" {
  description = "Desired managed node group size."
  type        = number
  default     = 2
}
variable "max_size" {
  description = "Maximum managed node group size."
  type        = number
  default     = 3
  validation {
    condition     = var.max_size >= var.min_size
    error_message = "max_size must be greater than or equal to min_size."
  }
}
variable "cluster_log_types" {
  description = "EKS control-plane log types enabled."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
variable "cloudwatch_log_retention_days" {
  description = "Retention for EKS control-plane CloudWatch logs."
  type        = number
  default     = 30
}
variable "enable_secrets_encryption" {
  description = "Create a KMS key and encrypt Kubernetes secrets."
  type        = bool
  default     = true
}
variable "admin_principal_arns" {
  description = "IAM role or user ARNs granted EKS cluster admin through access entries."
  type        = list(string)
  validation {
    condition     = length(var.admin_principal_arns) > 0 && alltrue([for arn in var.admin_principal_arns : startswith(arn, "arn:")])
    error_message = "Provide at least one IAM principal ARN for cluster administrator access."
  }
}
variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
