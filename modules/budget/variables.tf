variable "name" {
  description = "Name of the monthly AWS cost budget."
  type        = string
}

variable "amount" {
  description = "Monthly budget amount in USD."
  type        = number
  validation {
    condition     = var.amount > 0
    error_message = "Budget amount must be greater than zero."
  }
}

variable "email_address" {
  description = "Email subscriber for actual and forecasted budget alerts."
  type        = string
}

variable "tags" {
  description = "Tags applied to the budget."
  type        = map(string)
  default     = {}
}
