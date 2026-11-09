variable "cluster_name" {

  description = "EKS cluster name supplied by the environment root."
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
  default = {

  }

}
