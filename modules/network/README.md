# network

VPC with three public and three private subnets, internet gateway, optional NAT gateways, S3 gateway endpoint, optional ECR interface endpoints and optional VPC Flow Logs. Subnets carry the tags EKS and the AWS Load Balancer Controller need.

## Usage

```hcl
module "network" {
  source = "../../modules/network"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `name` | Name prefix for network resources. | yes |
| `cidr` | IPv4 CIDR for the VPC. | no |
| `availability_zones` | Three ap-southeast-1 availability zones. | no |
| `public_subnet_cidrs` | One public subnet CIDR per AZ. | no |
| `private_subnet_cidrs` | One private subnet CIDR per AZ. | no |
| `single_nat_gateway` | Use one NAT gateway for dev; false creates one per AZ. | no |
| `nodes_in_public_subnets` | Skip NAT gateways when EKS nodes use public subnets. | no |
| `enable_flow_logs` | Create VPC Flow Logs to CloudWatch. | no |
| `enable_ecr_endpoints` | Create paid ECR interface endpoints when avoiding NAT for image pulls. | no |
| `cluster_name` | EKS cluster name used for Kubernetes subnet discovery tags. | yes |
| `tags` | Common resource tags. | no |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID. |
| `vpc_cidr` | VPC CIDR. |
| `public_subnet_ids` | Public subnet IDs. |
| `private_subnet_ids` | Private subnet IDs for EKS and data services. |
