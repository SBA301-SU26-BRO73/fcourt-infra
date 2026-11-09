variable "aws_region" {
  description = "AWS region for the remote state bucket."
  type        = string
  default     = "ap-southeast-1"
}
variable "state_bucket_name" {
  description = "Globally unique bucket name for Terraform state."
  type        = string
  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "S3 bucket name must be 3 to 63 characters."
  }
}
