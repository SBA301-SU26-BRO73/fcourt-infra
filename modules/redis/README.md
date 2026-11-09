# redis

Private, encrypted ElastiCache Redis replication group reachable only from the EKS node security group. Used by prod.

## Usage

```hcl
module "redis" {
  source = "../../modules/redis"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `name` | Replication group name. | yes |
| `subnet_ids` | Private subnet IDs used for Redis placement. | yes |
| `node_security_group_id` | EKS node security group allowed to connect. | yes |
| `vpc_id` | VPC ID for Redis security group. | yes |
| `node_type` | ElastiCache node type. | no |
| `multi_az` | Enable automatic failover and a replica for production. | no |
| `tags` | Common resource tags. | no |

## Outputs

| Name | Description |
|---|---|
| `primary_endpoint_address` | Private Redis primary endpoint hostname. |
| `port` | Redis TLS port. |
