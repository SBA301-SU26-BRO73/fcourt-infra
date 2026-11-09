variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}
variable "cluster_arn" {
  description = "EKS cluster ARN used to constrain Pod Identity trust."
  type        = string
}
variable "env" {
  description = "Environment name used to scope Secrets Manager reads."
  type        = string
}
variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {

  }
}
