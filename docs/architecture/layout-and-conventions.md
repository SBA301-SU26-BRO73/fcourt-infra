# Layout and conventions

Moved from the old README.

```text
fcourt-infra/
├── envs/                      # root modules, one state each
│   ├── bootstrap/             # S3 state bucket (local state, applied once)
│   ├── shared/                # long-lived: ECR repos, GitHub OIDC + ECR push role, monthly budget, local media bucket + IAM user (S3 backend)
│   └── prod/                  # the only environment: VPC, EKS, Pod Identity, push, media (S3 backend)
├── modules/                   # reusable building blocks, each with README.md
│   ├── network/               # VPC, subnets, NAT, endpoints, flow logs
│   ├── eks/                   # cluster, node group, add-ons, access entries
│   ├── pod-identity/          # IAM role + Pod Identity for the Load Balancer Controller, generic extra associations
│   ├── ecr/                   # one repository per service (used by envs/shared only)
│   ├── media/                 # media bucket (prefix-scoped public read), optional per-service S3 Pod Identity roles
│   ├── push/                  # SNS FCM platform app, alarms, notification-service role, optional reminders
│   └── budget/                # monthly cost budget with email alerts
└── scripts/
    ├── up.sh                  # init + single apply of prod
    ├── down.sh                # stop Argo CD, delete Ingress/ALB/PVC, destroy prod only, list leftovers
    └── check.sh               # fmt + validate for bootstrap, shared, prod (offline)
```

Each environment root has the same files: `versions.tf` (Terraform and provider pins, backend), `providers.tf` (provider with `default_tags`), `main.tf` (`locals` and module calls), `variables.tf`, `outputs.tf`, plus `terraform.tfvars.example` and `backend.hcl.example`. Each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and `README.md`.

Conventions:

- Every root defines `local.tags` (`Project`, `Env`, `ManagedBy`), passes it to modules as `tags` and to the provider as `default_tags`. Modules never invent Project/Env tags themselves.
- Provider is pinned `hashicorp/aws ~> 5.80` and Terraform `>= 1.10.0, < 2.0.0` identically in every root and module.
- Resource names derive from `local.name` (`fcourt-prod`); the Kubernetes namespace is `fcourt-prod`.
- Inputs have descriptions; risky ones have validation (CIDRs, capacity type, node counts, `0.0.0.0/0` API access is rejected).
- Secrets (Firebase key) are never in tfvars; pass `TF_VAR_firebase_service_account_json` from a secret store.

