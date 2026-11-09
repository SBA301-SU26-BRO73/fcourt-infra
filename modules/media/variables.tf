variable "bucket_name" {
  description = "Globally unique media bucket name, for example fcourt-dev-media-<account-id>."
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN; constrains the Pod Identity trust policy of the per-service roles."
  type        = string
}

variable "role_name_prefix" {
  description = "Prefix for the per-service IAM roles (for example fcourt-dev-media)."
  type        = string
}

variable "force_destroy" {
  description = "Delete all objects when the bucket is destroyed. Enable only for throwaway environments (dev)."
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
