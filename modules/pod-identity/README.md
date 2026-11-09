# pod-identity

IAM roles and EKS Pod Identity associations for cluster add-ons (AWS Load Balancer Controller, External Secrets Operator), plus a generic `extra_associations` input for roles created elsewhere (for example the notification-service role from `push`). The Load Balancer Controller policy lives in `lbc-iam-policy.json` (the upstream policy published with the aws-load-balancer-controller release); refresh it when upgrading the controller.

## Usage

```hcl
module "pod_identity" {
  source = "../../modules/pod-identity"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `cluster_name` | EKS cluster name. | yes |
| `cluster_arn` | EKS cluster ARN; constrains the Pod Identity trust policy. | yes |
| `env` | Environment name (dev, prod); scopes Secrets Manager reads to /fcourt/<env>/*. | yes |
| `extra_associations` | Pod Identity associations for IAM roles created outside this module, keyed by a stable name. | no |
| `tags` | Common resource tags. | no |

## Outputs

| Name | Description |
|---|---|
| `load_balancer_controller_role_arn` | Pod Identity role ARN for the AWS Load Balancer Controller. |
| `external_secrets_role_arn` | Pod Identity role ARN for External Secrets Operator. |
| `extra_association_ids` | Pod Identity association IDs for extra_associations, keyed by name. |
