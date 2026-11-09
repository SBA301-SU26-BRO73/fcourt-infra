variable "cluster_name" {
  description = "Name of an existing EKS cluster. This module does not create a cluster."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the service account."
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name."
  type        = string
}

variable "role_arn" {
  description = "Existing IAM role ARN to associate with the service account."
  type        = string
}

variable "tags" {
  description = "Tags applied to the association when supported."
  type        = map(string)
  default     = {}
}
