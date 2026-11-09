variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN; constrains the Pod Identity trust policy."
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod); scopes Secrets Manager reads to /fcourt/<env>/*."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod."
  }
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
