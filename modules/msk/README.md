# msk

MSK Serverless Kafka cluster with IAM auth, reachable only from the EKS node security group. Used by prod.

## Usage

```hcl
module "msk" {
  source = "../../modules/msk"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `name` | MSK cluster name. | yes |
| `subnet_ids` | Private subnet IDs. Serverless requires at least two subnets in distinct AZs. | yes |
| `vpc_id` | VPC ID for broker security group. | yes |
| `node_security_group_id` | Only EKS nodes are allowed to connect to Kafka. | yes |
| `tags` | Common resource tags. | no |

## Outputs

| Name | Description |
|---|---|
| `cluster_arn` | MSK Serverless cluster ARN. |
| `bootstrap_brokers_sasl_iam` | TLS bootstrap brokers for SASL/IAM clients. |
