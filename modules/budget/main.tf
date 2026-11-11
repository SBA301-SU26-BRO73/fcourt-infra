resource "aws_budgets_budget" "monthly" {
  name         = var.name
  budget_type  = "COST"
  limit_amount = tostring(var.amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  cost_types {
    include_credit = false
    include_refund = false
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 5
    threshold_type             = "ABSOLUTE_VALUE"
    subscriber_email_addresses = [var.email_address]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 10
    threshold_type             = "ABSOLUTE_VALUE"
    subscriber_email_addresses = [var.email_address]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 15
    threshold_type             = "ABSOLUTE_VALUE"
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
