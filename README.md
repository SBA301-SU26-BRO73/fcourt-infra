# fcourt-infra

Terraform for the AWS side of FCourt (court booking system: Spring Boot microservices on Kafka), region `ap-southeast-1`. It creates the VPC, EKS cluster, ECR repositories, S3 buckets, the CloudFront + Route 53 + ACM web stack, SNS push, IAM Pod Identity roles and the cost budget. PostgreSQL, Kafka and Redis run inside the cluster and are managed by `fcourt-gitops`, not by Terraform.

There is one environment, `prod`. The cluster is cheap by design (two Spot nodes in one AZ, no NAT by default, EKS 1.35) and is brought up for a demo and destroyed right after.

## Role in the FCourt system

| Repo | Responsibility |
|---|---|
| **fcourt-infra** (this repo) | AWS infrastructure (Terraform) |
| `fcourt-gitops` | Argo CD apps and manifests that run on the EKS cluster created here; consumes the `gitops_values` output |
| `fcourt-backend` | Microservices; its CI pushes images to the ECR repositories created here through a GitHub OIDC role |
| `fcourt-web` | Web frontend deployed to the S3 bucket and CloudFront distribution created here (https://fcourt.donan.site) |
| `fcourt-flutter` | Android app calling the API through the same domain |

## Tech stack

Terraform `>= 1.10.0, < 2.0.0` (S3 native state locking), provider `hashicorp/aws ~> 5.80`, AWS CLI. Remote state in an S3 bucket created by `envs/bootstrap`.

## Project structure

```text
fcourt-infra/
|- envs/
|  |- bootstrap/   # S3 state bucket (local state, applied once)
|  |- shared/      # long-lived: ECR, GitHub OIDC + push/deploy roles, budget, local media bucket,
|  |               #   web stack (S3, CloudFront, Route 53, ACM)
|  |- prod/        # VPC, EKS, Pod Identity, SNS push, media bucket (destroyed after demos)
|- modules/        # network, eks, pod-identity, ecr, media, push, budget (each has a README.md)
|- scripts/        # up.sh, down.sh, check.sh, update-origin-record.sh
|- docs/           # see docs/README.md
```

Details and conventions: [docs/architecture/layout-and-conventions.md](docs/architecture/layout-and-conventions.md).

## Prerequisites

- Terraform `>= 1.10.0`, AWS CLI, `kubectl` (used by `down.sh` and the origin record script).
- An AWS CLI profile with admin-level access to the account (`export AWS_PROFILE=<profile>`).
- Firebase service account JSON for FCM push (passed through an environment variable, never in tfvars).

## Workflow

Order of work: bootstrap, shared, push images (CI or manual), prod.

```sh
export AWS_PROFILE=<profile>

# 1. once: state bucket
terraform -chdir=envs/bootstrap init
terraform -chdir=envs/bootstrap apply -var="state_bucket_name=<unique-bucket-name>"

# 2. once: long-lived shared resources
cp envs/shared/backend.hcl.example envs/shared/backend.hcl
cp envs/shared/terraform.tfvars.example envs/shared/terraform.tfvars
terraform -chdir=envs/shared init -backend-config=backend.hcl
terraform -chdir=envs/shared apply

# 3. per demo: prod (cluster and data plane)
cp envs/prod/backend.hcl.example envs/prod/backend.hcl
cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars
export TF_VAR_firebase_service_account_json="$(cat /path/to/firebase-service-account.json)"
sh scripts/up.sh          # init + one apply of envs/prod
sh scripts/down.sh        # stop Argo CD, delete ALB/PVCs, destroy envs/prod only
```

After `up.sh`, continue with the `fcourt-gitops` README (Argo CD, secrets, root app), then run `sh scripts/update-origin-record.sh` once the gateway Ingress has an address. Full steps: [docs/operations](docs/operations/).

| Script | Purpose |
|---|---|
| `scripts/up.sh` | Checks prerequisites (including that `fcourt/gateway-service` has an image in ECR), then `init` and `apply` of `envs/prod` |
| `scripts/down.sh` | Tears down Argo CD apps, Ingress/ALB, PVCs, then `terraform destroy` of `envs/prod`; never touches `envs/shared` |
| `scripts/update-origin-record.sh` | Points `origin.<web domain>` (CloudFront API origin) at the current ALB |
| `scripts/check.sh` | Offline `terraform fmt -check` and `validate` for bootstrap, shared, prod |

## Configuration

Each root has `terraform.tfvars.example` and `backend.hcl.example`; the real `terraform.tfvars`, `backend.hcl`, state and plan files are git-ignored. Main inputs of `envs/prod`:

| Variable | Meaning |
|---|---|
| `aws_region` | Region |
| `vpc_cidr` | VPC CIDR; subnets are derived from it |
| `cluster_version`, `eks_instance_types`, `eks_capacity_type` (`SPOT`/`ON_DEMAND`), `eks_min_size`, `eks_desired_size`, `eks_max_size`, `eks_root_volume_size` | Cluster and node group sizing |
| `cluster_public_access_cidrs` | Required. CIDRs allowed to reach the public Kubernetes API (use your own client IP as a `/32`). `0.0.0.0/0` is rejected by validation. Update it when your IP changes, otherwise `kubectl` times out. |
| `admin_principal_arns` | Required. IAM principals granted cluster-admin |
| `firebase_service_account_json` | Sensitive; set through `TF_VAR_firebase_service_account_json` |
| `nodes_in_public_subnets` | `true` skips the NAT gateway (short demos only) |
| `enable_flow_logs`, `enable_interface_endpoints`, `enable_secrets_encryption`, `eks_cluster_log_types` | Optional extras, off by default to save cost |

Never commit secrets, state files or real tfvars. Outputs worth knowing: `gitops_values` from `envs/prod` (consumed by `fcourt-gitops/scripts/apply-terraform-outputs.sh`), and from `envs/shared` the role ARNs and web values that go into the GitHub repository variables of `fcourt-backend` (`AWS_ECR_PUSH_ROLE_ARN`) and `fcourt-web` (`WEB_BUCKET`, `WEB_DISTRIBUTION_ID`, `AWS_WEB_DEPLOY_ROLE_ARN`).

## CI/CD and deployment

- There is no CI workflow in this repo. Run `sh scripts/check.sh` before every PR (fmt and validate, no AWS access needed).
- Infrastructure is applied manually from a workstation with the commands above; review `terraform plan` before `apply`.
- Other repos deploy through OIDC roles created in `envs/shared`: `fcourt-backend` pushes images to ECR, `fcourt-web` syncs to S3 and invalidates CloudFront.
- Shut down after every demo (`sh scripts/down.sh`); leftover EBS volumes and ALBs keep costing money. Cost notes: [docs/operations/cost-notes.md](docs/operations/cost-notes.md).

## Testing

`sh scripts/check.sh` runs `terraform fmt -check -recursive` and `init -backend=false` plus `validate` for every root. It needs provider downloads but no AWS credentials. Use `terraform plan` for the real diff.

## Contributing

- Branch from `main` with a prefix such as `feat/`, `fix/`, `docs/`, `chore/`; open a PR into `main`.
- Commit messages and PR titles are in English (`type(scope): message`). Bodies may be Vietnamese.
- Keep the conventions: `local.tags` on every root, pinned provider versions, descriptions and validation on inputs.
- Do not commit `*.tfstate`, `*.tfvars`, `backend.hcl`, plans or credentials.
