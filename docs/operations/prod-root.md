# Prod root

Moved from the old README.

## 3. Prod root: plan and apply

```sh
export AWS_PROFILE=tpn12
export TF_VAR_firebase_service_account_json="$(cat /path/to/firebase-service-account.json)"

terraform -chdir=envs/prod init -backend-config=backend.hcl
terraform -chdir=envs/prod plan
terraform -chdir=envs/prod apply
```

Created by `envs/prod`: VPC `fcourt-prod` (subnets derived from `vpc_cidr`; no NAT by default because `nodes_in_public_subnets = true`), EKS cluster `fcourt-prod` (Spot nodes in one AZ, EBS CSI with its own Pod Identity role and tagged volumes), Pod Identity roles for the Load Balancer Controller, EBS CSI, notification-service and five media services, the SNS FCM platform application, the media bucket `fcourt-prod-media-<account_id>` (`force_destroy = true`, since the cluster is torn down per demo). The monthly budget lives in `envs/shared` so it survives `scripts/down.sh`.

`terraform -chdir=envs/prod output -json gitops_values` prints what `fcourt-gitops` needs: `region`, `cluster_name`, `namespace`, `vpc_id`, `push_platform_application_arn`, `media_bucket_name`, `media_public_base_url`. Other outputs: ECR registry URL, role ARNs, cluster endpoint and CA.

