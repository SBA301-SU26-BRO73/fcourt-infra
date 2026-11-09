variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}
variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to push images through OIDC."
  type        = string
  default     = "SBA301-SU26-BRO73/fcourt-backend"
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}
variable "github_refs" {
  description = "Branch names (refs/heads/<name>) allowed to assume the push role."
  type        = list(string)
  default     = ["dev", "main"]
  validation {
    condition     = length(var.github_refs) > 0 && !contains(var.github_refs, "*")
    error_message = "github_refs must list explicit branch names, not a wildcard."
  }
}
variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false when the account already has one (it is then looked up)."
  type        = bool
  default     = true
}
variable "tagged_image_count" {
  description = "Tagged images kept per repository."
  type        = number
  default     = 10
}
variable "untagged_image_retention_days" {
  description = "Days before untagged images expire."
  type        = number
  default     = 7
}
