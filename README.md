# fcourt-infra

Terraform for FCourt (court-booking system: Spring Boot microservices on Kafka) on AWS, region `ap-southeast-1`.

- **dev** is the cheap demo environment: two Spot nodes (t3.large/t3a.large/m6i.large), EKS 1.35, no NAT, PostgreSQL/Kafka/Redis run inside the cluster (managed by the `fcourt-gitops` repo). Create it for a demo, destroy it right after.
- **prod** uses managed services: RDS PostgreSQL, MSK Serverless, ElastiCache Redis, three NAT gateways, Multi-AZ.

Use the AWS CLI profile `tpn12` for every command (`export AWS_PROFILE=tpn12`). Terraform `>= 1.10.0` is required (S3 native state locking).

## Layout

```text
fcourt-infra/
├── envs/                      # root modules, one state each
│   ├── bootstrap/             # S3 state bucket (local state, applied once)
│   ├── shared/                # long-lived: ECR repos fcourt/<service>, GitHub Actions OIDC + ECR push role (S3 backend)
│   ├── dev/                   # demo environment (S3 backend)
│   ├── prod/                  # production (S3 backend)
│   └── sandbox/
│       └── push-test/         # throwaway SNS push test, NOT a real environment (local state)
├── modules/                   # reusable building blocks, each with README.md
│   ├── network/               # VPC, subnets, NAT, endpoints, flow logs
│   ├── eks/                   # cluster, node group, add-ons, access entries
│   ├── pod-identity/          # IAM roles + Pod Identity for LBC and External Secrets, generic extra associations
│   ├── ecr/                   # one repository per service (used by envs/shared only)
│   ├── media/                 # per-env media bucket (prefix-scoped public read) and per-service S3 Pod Identity roles
│   ├── push/                  # SNS FCM platform app, alarms, notification-service role, optional reminders
│   ├── budget/                # monthly cost budget with email alerts
│   ├── rds/                   # PostgreSQL (prod)
│   ├── msk/                   # Kafka Serverless (prod)
│   └── redis/                 # ElastiCache Redis (prod)
└── scripts/
    ├── up.sh                  # init + single apply of dev
    ├── down.sh                # stop Argo CD, delete Ingress/ALB/PVC, destroy dev only, list leftovers
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
| `sh scripts/up.sh` | Checks files, profile and `TF_VAR_firebase_service_account_json`, warns if ECR is missing, then `init` and one `apply` for `envs/dev`. |
| `sh scripts/down.sh` | Stops Argo CD (selfHeal), deletes Ingresses and waits for the ALB and its security groups to vanish, deletes `fcourt-dev`/`data` namespaces and PVCs and waits for EBS volumes, then `terraform destroy` of `envs/dev` only, then read-only leftover inventory. Never touches `envs/shared`. |
| `sh scripts/check.sh` | `terraform fmt -check` and `init -backend=false` + `validate` for bootstrap, dev, shared, prod and sandbox roots. Needs provider download, no AWS access. |

## Cost notes

Prices below are rough estimates from memory (Singapore, 4-hour demo), not quotes. Check the AWS pricing pages.

Dev stays the cheapest environment by design:

- Node group is `SPOT`, min/desired/max `2/2/2`, 20 GiB gp3 root, IMDSv2. Three interchangeable 2 vCPU/8 GiB types (`t3.large`, `t3a.large`, `m6i.large`) improve Spot availability. Spot can be reclaimed at any time; use On-Demand if a demo must not be interrupted. One 8 GiB node is not enough for 12 services, Eureka, the gateway and data.
- `nodes_in_public_subnets = true` puts nodes in public subnets and skips the NAT gateway (about $0.06/h saved). Nodes get public IPs but security groups allow no inbound traffic and the API is limited to `cluster_public_access_cidrs`. Use for short demos only.
- Control-plane logging, VPC flow logs, interface endpoints and KMS secrets encryption are off by default.
- Budget alert: `monthly_budget_usd = 20`, emails at 50% and 100% actual and 100% forecast. Alerts do not stop spending.
- Rough dev cost while running: EKS control plane ~$0.10/h, one Spot node ~$0.05-0.15/h, ALB ~$0.02-0.03/h. That is roughly $1-2 for a 4-hour demo.

**Shut down after the demo** (`sh scripts/down.sh`). Things that still cost money after destroy if forgotten: leftover EBS volumes (PVCs), ALBs created by Ingress, old state bucket versions, active SNS resources.

Prod defaults (3 NAT gateways, at least 3 workers, Multi-AZ RDS and Redis, flow logs) are far more expensive. Never run prod to "try it out".

Sizing: request memory is about 8 GiB for everything; two 8 GiB nodes is the minimum. If pods stay `Pending` or are `OOMKilled`, check `kubectl top nodes/pods`.

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

## Shared root: ECR and CI push role (apply once, keep forever)

`envs/shared` owns what must survive dev destroys: 14 ECR repositories `fcourt/<service>` (12 services plus `eureka-server` and `gateway-service`) (scan on push, mutable tags so CI can move `:dev`, keep last 10 tagged images, untagged expire after 7 days), the GitHub Actions OIDC provider and the IAM role `fcourt-shared-github-ecr-push`. The role trusts only `repo:SBA301-SU26-BRO73/fcourt-backend:ref:refs/heads/{dev,main}` and can push only to those repositories. `scripts/down.sh` never touches it.

```sh
export AWS_PROFILE=tpn12
cp envs/shared/backend.hcl.example envs/shared/backend.hcl          # same bucket, key fcourt/shared/...
cp envs/shared/terraform.tfvars.example envs/shared/terraform.tfvars
terraform -chdir=envs/shared init -backend-config=backend.hcl
terraform -chdir=envs/shared apply                                   # 27 resources on an empty account
terraform -chdir=envs/shared output github_ecr_push_role_arn         # -> repo variable AWS_ECR_PUSH_ROLE_ARN in fcourt-backend
```

If the account already has a GitHub OIDC provider, set `create_github_oidc_provider = false`. `envs/dev` and `envs/prod` no longer create ECR; their `ecr_registry_url` output is derived from the account id and region. prod never applied ECR in a real state, so no `moved` blocks are needed.

## Bring-up order (dev)

1. `bootstrap` (once), then `shared` (once), then CI pushes images on merge to `dev` (or push manually).
2. `sh scripts/up.sh` runs one `terraform apply` of `envs/dev` (module `push` takes the cluster ARN from `module.eks`, so no `-target` is needed).
3. Follow `fcourt-gitops` README for Argo CD, secrets and the root app.
4. `sh scripts/down.sh` when done.
