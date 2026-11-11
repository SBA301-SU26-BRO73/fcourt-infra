# budget

Monthly AWS cost budget with email alerts at 5, 10 and 15 USD actual and 100% forecasted spend. Credits and refunds are excluded from the cost.

## Usage

```hcl
module "budget" {
  source = "../../modules/budget"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `name` | Name of the monthly AWS cost budget. | yes |
| `amount` | Monthly budget amount in USD (default 20). | no |
| `email_address` | Email subscriber for actual and forecasted budget alerts. | yes |
| `tags` | Tags applied to the budget. | no |

## Outputs

| Name | Description |
|---|---|
| `budget_name` | Name of the monthly cost budget. |
| `budget_arn` | ARN of the monthly cost budget. |
