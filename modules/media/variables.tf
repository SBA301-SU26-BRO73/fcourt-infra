variable "bucket_name" {
  description = "Globally unique media bucket name, for example fcourt-prod-media-<account-id>."
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN; constrains the Pod Identity trust policy of the per-service roles. Required when create_service_roles is true."
  type        = string
  default     = ""
  validation {
    condition     = !var.create_service_roles || var.cluster_arn != ""
    error_message = "cluster_arn is required when create_service_roles is true."
  }
}

variable "role_name_prefix" {
  description = "Prefix for the per-service IAM roles (for example fcourt-prod-media)."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Delete all objects when the bucket is destroyed. Enable only for throwaway buckets."
  type        = bool
  default     = false
}

variable "public_prefixes" {
  description = "Key prefixes readable anonymously over HTTPS (public images). Everything else stays private."
  type        = list(string)
  default     = ["avatars/", "branches/", "reviews/"]
}

variable "private_ia_prefixes" {
  description = "Private prefixes moved to STANDARD_IA after 90 days. Objects are never expired automatically (financial and legal records)."
  type        = list(string)
  default     = ["receipts/", "refund-proofs/", "owner-documents/"]
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}

variable "create_service_roles" {
  description = "Create the per-service Pod Identity roles (needs cluster_arn and role_name_prefix). Set false for a bucket used outside EKS, for example local docker-compose development."
  type        = bool
  default     = true
}
