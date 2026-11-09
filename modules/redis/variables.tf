variable "name" {
  description = "Replication group name."
  type        = string
}
variable "subnet_ids" {
  description = "Private subnet IDs used for Redis placement."
  type        = list(string)
}
variable "node_security_group_id" {
  description = "EKS node security group allowed to connect."
  type        = string
}
variable "vpc_id" {
  description = "VPC ID for Redis security group."
  type        = string
}
variable "node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t4g.micro"
}
variable "multi_az" {
  description = "Enable automatic failover and a replica for production."
  type        = bool
  default     = false
}
variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {

  }
}
