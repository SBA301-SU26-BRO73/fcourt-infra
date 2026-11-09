variable "name" {
  description = "MSK cluster name."
  type        = string
}
variable "subnet_ids" {
  description = "Private subnet IDs. Serverless requires at least two subnets in distinct AZs."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "MSK Serverless needs at least two private subnets."
  }
}
variable "vpc_id" {
  description = "VPC ID for broker security group."
  type        = string
}
variable "node_security_group_id" {
  description = "Only EKS nodes are allowed to connect to Kafka."
  type        = string
}
variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
