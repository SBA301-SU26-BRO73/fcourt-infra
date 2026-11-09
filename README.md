# fcourt-infra

Terraform for FCourt (court-booking system: Spring Boot microservices on Kafka) on AWS, region `ap-southeast-1`.

- **dev** is the cheap demo environment: one Spot node, no NAT, PostgreSQL/Kafka/Redis run inside the cluster (managed by the `fcourt-gitops` repo). Create it for a demo, destroy it right after.
- **prod** uses managed services: RDS PostgreSQL, MSK Serverless, ElastiCache Redis, three NAT gateways, Multi-AZ.

Use the AWS CLI profile `tpn12` for every command (`export AWS_PROFILE=tpn12`). Terraform `>= 1.10.0` is required (S3 native state locking).

## Layout

```text
fcourt-infra/
├── envs/                      # root modules, one state each
│   ├── bootstrap/             # S3 state bucket (local state, applied once)
│   ├── dev/                   # demo environment (S3 backend)
│   ├── prod/                  # production (S3 backend)
│   └── sandbox/
│       └── push-test/         # throwaway SNS push test, NOT a real environment (local state)
├── modules/                   # reusable building blocks, each with README.md
│   ├── network/               # VPC, subnets, NAT, endpoints, flow logs
│   ├── eks/                   # cluster, node group, add-ons, access entries
│   ├── pod-identity/          # IAM roles + Pod Identity for LBC and External Secrets, generic extra associations
│   ├── ecr/                   # one repository per service
│   ├── push/                  # SNS FCM platform app, alarms, notification-service role, optional reminders
│   ├── budget/                # monthly cost budget with email alerts
│   ├── rds/                   # PostgreSQL (prod)
│   ├── msk/                   # Kafka Serverless (prod)
│   └── redis/                 # ElastiCache Redis (prod)
└── scripts/
    ├── up.sh                  # init + apply dev
    ├── down.sh                # clean Ingress/PVC, destroy dev, list leftovers
    └── check.sh               # fmt + validate for all roots (offline)
```

Each environment root has the same files: `versions.tf` (Terraform and provider pins, backend), `providers.tf` (provider with `default_tags`), `main.tf` (`locals` and module calls), `variables.tf`, `outputs.tf`, plus `terraform.tfvars.example` and `backend.hcl.example`. Each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and `README.md`.

Conventions:

- Every root defines `local.tags` (`Project`, `Env`, `ManagedBy`), passes it to modules as `tags` and to the provider as `default_tags`. Modules never invent Project/Env tags themselves.
- Provider is pinned `hashicorp/aws ~> 5.80` and Terraform `>= 1.10.0, < 2.0.0` identically in every root and module.
- Resource names derive from `local.name` (`fcourt-dev`, `fcourt-prod`).
- Inputs have descriptions; risky ones have validation (CIDRs, capacity type, node counts, `0.0.0.0/0` API access is rejected).
- Secrets (Firebase key) are never in tfvars; pass `TF_VAR_firebase_service_account_json` from a secret store.

## Bootstrap the state bucket (once)

```sh
export AWS_PROFILE=tpn12
terraform -chdir=envs/bootstrap init
terraform -chdir=envs/bootstrap apply -var='state_bucket_name=fcourt-terraform-state-ACCOUNT-UNIQUE'
```

The bucket is versioned, encrypted, private, TLS-only and `prevent_destroy`. It is kept after demos. Then, per environment:

```sh
cp envs/dev/backend.hcl.example envs/dev/backend.hcl                 # set bucket
cp envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars       # set admin ARN, your IP CIDR, budget email
```

`backend.hcl`, `terraform.tfvars`, state and plan files are gitignored. Do not commit them.

## Plan and apply per environment

```sh
export AWS_PROFILE=tpn12
export TF_VAR_firebase_service_account_json="$(cat /path/to/firebase-service-account.json)"

terraform -chdir=envs/dev init -backend-config=backend.hcl
terraform -chdir=envs/dev plan
terraform -chdir=envs/dev apply

# prod: same commands with envs/prod (review the plan carefully; it is expensive)
```

`terraform -chdir=envs/<env> output` prints cluster name, ECR URLs and role ARNs consumed by `fcourt-gitops`.

## Scripts

| Script | What it does |
|---|---|
| `sh scripts/up.sh` | Checks `backend.hcl` and `terraform.tfvars` exist, then `init` and `apply` for `envs/dev`. |
| `sh scripts/down.sh` | Deletes all Ingresses and PVCs (they own ALBs and EBS volumes), waits up to 10 minutes for them to vanish, runs `terraform destroy` for `envs/dev`, then lists leftover tagged load balancers, volumes, ENIs and NAT gateways (read-only; nothing is deleted by hand). |
| `sh scripts/check.sh` | `terraform fmt -check` and `init -backend=false` + `validate` for bootstrap, dev, prod and sandbox roots. Needs provider download, no AWS access. |

## Cost notes

Prices below are rough estimates from memory (Singapore, 4-hour demo), not quotes. Check the AWS pricing pages.

Dev stays the cheapest environment by design:

- Node group is `SPOT`, min/desired/max `1/1/2`, 20 GiB gp3 root, IMDSv2. Four interchangeable 4 vCPU/16 GiB types (`t3a.xlarge`, `t3.xlarge`, `m5a.xlarge`, `m5.xlarge`) improve Spot availability. Spot can be reclaimed at any time; use On-Demand or two nodes if a demo must not be interrupted.
- `nodes_in_public_subnets = true` puts nodes in public subnets and skips the NAT gateway (about $0.06/h saved). Nodes get public IPs but security groups allow no inbound traffic and the API is limited to `cluster_public_access_cidrs`. Use for short demos only.
- Control-plane logging, VPC flow logs, interface endpoints and KMS secrets encryption are off by default.
- Budget alert: `monthly_budget_usd = 20`, emails at 50% and 100% actual and 100% forecast. Alerts do not stop spending.
- Rough dev cost while running: EKS control plane ~$0.10/h, one Spot node ~$0.05-0.15/h, ALB ~$0.02-0.03/h. That is roughly $1-2 for a 4-hour demo.

**Shut down after the demo** (`sh scripts/down.sh`). Things that still cost money after destroy if forgotten: leftover EBS volumes (PVCs), ALBs created by Ingress, ECR image storage, old state bucket versions, active SNS resources.

Prod defaults (3 NAT gateways, at least 3 workers, Multi-AZ RDS and Redis, flow logs) are far more expensive. Never run prod to "try it out".

Sizing caveat: one xlarge node for ~12 Spring Boot services plus PostgreSQL, Kafka and Redis is an unmeasured estimate. If pods stay `Pending` or are `OOMKilled`, check `kubectl top nodes/pods` and move to 8 vCPU/32 GiB types or set min/desired to 2.

## Sandbox: push notification test

`envs/sandbox/push-test` creates only the SNS FCM platform application and a CloudWatch alarm, without EKS, so Firebase delivery can be tried cheaply. It uses **local state** that contains the Firebase key: keep `terraform.tfstate` on this machine, never copy or commit it.

```sh
export AWS_PROFILE=tpn12
export TF_VAR_firebase_service_account_json="$(cat /path/to/firebase-service-account.json)"
terraform -chdir=envs/sandbox/push-test init
terraform -chdir=envs/sandbox/push-test apply
# when done
terraform -chdir=envs/sandbox/push-test destroy
unset TF_VAR_firebase_service_account_json
```

## Notes on state-preserving renames

`envs/dev/moved.tf` and `envs/prod/moved.tf` record the merge of the old `workload-identity` and `pod-identity` modules into `modules/pod-identity` (`module.workload_identity` is now `module.pod_identity`, and the notification-service association became `extra_associations["notification-service"]`). A plan after pulling this change shows moves, not recreation. They can be deleted once every state has applied them.

## Out of scope

No DNS/Route 53, ACM, WAF, CloudFront, VPN, bastion, Helm releases, Kubernetes namespaces/secrets, SQL migrations, Kafka topics/ACLs or monitoring stack. Those belong to `fcourt-gitops` or later work. The Firebase credential is stored in Terraform state through the SNS platform application, so restrict access to state.
