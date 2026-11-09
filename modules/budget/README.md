# budget

Monthly AWS cost budget with email alerts at 50% and 100% actual and 100% forecasted spend.

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
| `amount` | Monthly budget amount in USD. | yes |
| `email_address` | Email subscriber for actual and forecasted budget alerts. | yes |
| `tags` | Tags applied to the budget. | no |

## Outputs

| Name | Description |
|---|---|
| `budget_name` | Name of the monthly cost budget. |
| `budget_arn` | ARN of the monthly cost budget. |
