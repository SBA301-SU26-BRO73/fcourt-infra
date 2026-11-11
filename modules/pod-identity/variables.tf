variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN; constrains the Pod Identity trust policy."
  type        = string
}

variable "extra_associations" {
  description = "Pod Identity associations for IAM roles created outside this module, keyed by a stable name."
  type = map(object({
    namespace       = string
    service_account = string
    role_arn        = string
  }))
  default = {}
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
