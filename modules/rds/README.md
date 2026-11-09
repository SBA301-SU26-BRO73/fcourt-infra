# rds

Private, encrypted RDS PostgreSQL instance with a managed master secret. Reachable only from the EKS node security group. Used by prod.

## Usage

```hcl
module "rds" {
  source = "../../modules/rds"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `name` | RDS identifier prefix. | yes |
| `env` | Environment name. | yes |
| `subnet_ids` | Private subnet IDs for the DB subnet group. | yes |
| `vpc_id` | VPC ID containing RDS and EKS nodes. | yes |
| `node_security_group_id` | Only this EKS node security group is allowed to connect. | yes |
| `instance_class` | RDS PostgreSQL instance class. | no |
| `multi_az` | Enable Multi-AZ standby for production. | no |
| `allocated_storage` | Initial encrypted gp3 storage in GiB. | no |
| `engine_version` | PostgreSQL engine minor version   must be offered in ap-southeast-1. | no |
| `tags` | Common resource tags. | no |

## Outputs

| Name | Description |
|---|---|
| `address` | Private PostgreSQL endpoint hostname. |
| `port` | PostgreSQL port. |
| `database` | Initial database name   create service-specific databases as described in README. |
| `master_secret_arn` | Secrets Manager ARN for RDS-managed master credentials. |
| `security_group_id` | RDS security group ID. |
