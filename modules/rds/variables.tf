variable "name" {
  description = "RDS identifier prefix."
  type        = string
}
variable "env" {
  description = "Environment name."
  type        = string
}
variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group."
  type        = list(string)
}
variable "vpc_id" {
  description = "VPC ID containing RDS and EKS nodes."
  type        = string
}
variable "node_security_group_id" {
  description = "Only this EKS node security group is allowed to connect."
  type        = string
}
variable "instance_class" {
  description = "RDS PostgreSQL instance class."
  type        = string
  default     = "db.t4g.micro"
}
variable "multi_az" {
  description = "Enable Multi-AZ standby for production."
  type        = bool
  default     = false
}
variable "allocated_storage" {
  description = "Initial encrypted gp3 storage in GiB."
  type        = number
  default     = 30
}
variable "engine_version" {
  description = "PostgreSQL engine minor version   must be offered in ap-southeast-1."
  type        = string
  default     = "16.4"
}
variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {

  }
}
