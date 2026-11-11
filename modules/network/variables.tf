variable "name" {
  description = "Name prefix for network resources."
  type        = string
}
variable "cidr" {
  description = "IPv4 CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR block."
  }
}
variable "availability_zones" {
  description = "Three ap-southeast-1 availability zones."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  validation {
    condition     = length(var.availability_zones) == 3
    error_message = "Exactly three availability zones are required."
  }
}
variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per AZ."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "Provide three public subnet CIDRs."
  }
}
variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per AZ."
  type        = list(string)
  default     = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Provide three private subnet CIDRs."
  }
}
variable "single_nat_gateway" {
  description = "Use one NAT gateway for a single NAT (cheap); false creates one per AZ."
  type        = bool
  default     = true
}
variable "nodes_in_public_subnets" {
  description = "Skip NAT gateways when EKS nodes use public subnets."
  type        = bool
  default     = false
}
variable "enable_flow_logs" {
  description = "Create VPC Flow Logs to CloudWatch."
  type        = bool
  default     = false
}
variable "enable_ecr_endpoints" {
  description = "Create paid ECR interface endpoints when avoiding NAT for image pulls."
  type        = bool
  default     = false
}
variable "cluster_name" {
  description = "EKS cluster name used for Kubernetes subnet discovery tags."
  type        = string
}
variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
