variable "repository_prefix" {
  description = "Prefix used for ECR repository names."
  type        = string
  default     = "fcourt"
}

variable "services" {
  description = "Service names that receive one ECR repository each."
  type        = list(string)
  default = [
    "auth-service",
    "subscription-service",
    "facility-service",
    "reporting-service",
    "discovery-service",
    "voucher-service",
    "slot-hold-engine",
    "booking-service",
    "payment-service",
    "staff-operations-service",
    "notification-service",
    "pos-retail-service",
    "gateway-service"
  ]
  validation {
    condition     = length(var.services) > 0 && length(distinct(var.services)) == length(var.services)
    error_message = "services must contain unique, non-empty service names."
  }
}

variable "tagged_image_count" {
  description = "Maximum number of tagged images to retain per repository."
  type        = number
  default     = 30
  validation {
    condition     = var.tagged_image_count >= 1
    error_message = "tagged_image_count must be at least 1."
  }
}

variable "untagged_image_retention_days" {
  description = "Age in days after which untagged images expire."
  type        = number
  default     = 7
  validation {
    condition     = var.untagged_image_retention_days >= 1
    error_message = "untagged_image_retention_days must be at least 1."
  }
}

variable "image_tag_mutability" {
  description = "MUTABLE lets CI move tags such as dev; IMMUTABLE forbids re-pushing a tag."
  type        = string
  default     = "IMMUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
  default     = {}
}
