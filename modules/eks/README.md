# eks

EKS cluster, managed node group (Spot or On-Demand), core add-ons (vpc-cni, coredns, kube-proxy, Pod Identity Agent, EBS CSI), access entries for admins, optional KMS secrets encryption and control-plane logging.

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `cluster_name` | Unique EKS cluster name. | yes |
| `cluster_version` | Kubernetes version supported by EKS in the target region. | no |
| `private_subnet_ids` | Private subnet IDs for the EKS control plane and worker nodes. | yes |
| `public_subnet_ids` | Public subnet IDs, used only when nodes_in_public_subnets is true. | no |
| `nodes_in_public_subnets` | Place nodes in public subnets and assign public IPs. | no |
| `capacity_type` | Managed node group capacity type, ON_DEMAND or SPOT. | no |
| `vpc_id` | VPC ID for EKS security groups. | yes |
| `cluster_public_access_cidrs` | CIDRs permitted to reach the public Kubernetes API endpoint. | yes |
| `root_volume_size` | Encrypted gp3 worker root volume size in GiB. | no |
| `instance_types` | EC2 instance types used by the managed node group. | no |
| `min_size` | Minimum managed node group size. | no |
| `desired_size` | Desired managed node group size. | no |
| `max_size` | Maximum managed node group size. | no |
| `cluster_log_types` | EKS control-plane log types enabled. | no |
| `cloudwatch_log_retention_days` | Retention for EKS control-plane CloudWatch logs. | no |
| `enable_secrets_encryption` | Create a KMS key and encrypt Kubernetes secrets. | no |
| `admin_principal_arns` | IAM role or user ARNs granted EKS cluster admin through access entries. | yes |
| `tags` | Common resource tags. | no |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | EKS cluster name. |
| `cluster_arn` | EKS cluster ARN. |
| `cluster_endpoint` | EKS Kubernetes API endpoint. |
| `cluster_certificate_authority_data` | Base64 cluster certificate authority data. |
| `node_security_group_id` | Managed node security group ID for data-layer ingress rules. |
| `node_role_arn` | Managed node role ARN. |
| `ebs_csi_role_arn` | Pod Identity role ARN for the EBS CSI add-on. |
