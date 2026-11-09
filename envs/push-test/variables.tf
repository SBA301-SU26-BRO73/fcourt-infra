variable "aws_region" {

  description = "AWS region for the standalone SNS push test."
  type        = string
  default     = "ap-southeast-1"

}

variable "firebase_service_account_json" {

  description = "Firebase service-account JSON content. Supplied securely through TF_VAR_firebase_service_account_json."
  type        = string
  sensitive   = true

}
