resource "aws_budgets_budget" "monthly" {
  name         = var.name
  budget_type  = "COST"
  limit_amount = tostring(var.amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.email_address]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.email_address]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "FORECASTED"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.email_address]
  }

  tags = var.tags
}
