# fcourt-infra

Terraform for FCourt (court-booking system: Spring Boot microservices on Kafka) on AWS, region `ap-southeast-1`.

There is **one environment, `prod`**. Everything data-related (PostgreSQL, Kafka, Redis) runs inside the Kubernetes cluster and is managed by the `fcourt-gitops` repo; Terraform only creates the AWS pieces around it. The cluster is cheap by design (two Spot nodes in a single AZ, no NAT by default, EKS 1.35) and is brought up for a demo and destroyed right after (`scripts/up.sh`, `scripts/down.sh`).

Use the AWS CLI profile `tpn12` for every command (`export AWS_PROFILE=tpn12`). Terraform `>= 1.10.0` is required (S3 native state locking).

Order of work: **bootstrap -> shared -> push images (CI or manual) -> prod**.

## Layout

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

## 1. Bootstrap the state bucket (once)

```sh
export AWS_PROFILE=tpn12
terraform -chdir=envs/bootstrap init
terraform -chdir=envs/bootstrap apply -var='state_bucket_name=fcourt-terraform-state-ACCOUNT-UNIQUE'
```

The bucket is versioned, encrypted, private, TLS-only and `prevent_destroy`. It is kept after demos. Then, per root (`shared`, `prod`):

```sh
cp envs/prod/backend.hcl.example envs/prod/backend.hcl                 # set bucket
cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars       # set admin ARN and your IP CIDR
```

`backend.hcl`, `terraform.tfvars`, state and plan files are gitignored. Do not commit them.

## 2. Shared root: ECR, CI push role, local media bucket (apply once, keep forever)

`envs/shared` owns what must survive prod destroys:

- 13 ECR repositories `fcourt/<service>` (12 services plus `gateway-service`): scan on push, mutable tags so CI can move `:latest`, keep last 3 tagged images, untagged expire after 7 days.
- The GitHub Actions OIDC provider and the IAM role `fcourt-shared-github-ecr-push`. The role trusts only `repo:SBA301-SU26-BRO73/fcourt-backend:ref:refs/heads/{dev,main}` and can push only to those repositories.
- The **local media bucket** `fcourt-local-media-<account_id>` and the IAM user `fcourt-local-s3` (see below).

`scripts/down.sh` never touches it.

```sh
export AWS_PROFILE=tpn12
cp envs/shared/backend.hcl.example envs/shared/backend.hcl          # same bucket, key fcourt/shared/...
cp envs/shared/terraform.tfvars.example envs/shared/terraform.tfvars
terraform -chdir=envs/shared init -backend-config=backend.hcl
terraform -chdir=envs/shared apply
terraform -chdir=envs/shared output github_ecr_push_role_arn         # -> repo variable AWS_ECR_PUSH_ROLE_ARN in fcourt-backend
```

If the account already has a GitHub OIDC provider, set `create_github_oidc_provider = false`. `envs/prod` does not create ECR; its `ecr_registry_url` output is derived from the account id and region.

### Local media bucket and IAM user (docker-compose development)

Compose in `fcourt-backend` talks to a real S3 bucket instead of MinIO. The bucket is separate from the EKS bucket in `envs/prod`: the image-cleanup job of one environment deletes objects it does not know, so sharing a bucket would make local and EKS delete each other's images.

- Bucket `fcourt-local-media-<account_id>`, built with `modules/media` (`create_service_roles = false`): public read only for `avatars/`, `branches/`, `reviews/`; everything else private (presigned URLs). Not `force_destroy`.
- IAM user `fcourt-local-s3` with an inline policy limited to that bucket: `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on `bucket/*` and `s3:ListBucket` on the bucket.
- Outputs: `local_media_bucket_name`, `local_media_public_base_url` (`https://<bucket>.s3.ap-southeast-1.amazonaws.com`), `local_s3_user_name`.

Terraform deliberately does **not** create an access key (the secret would be stored in state). After applying `envs/shared`, create it once by hand and put it in the gitignored `.env` of `fcourt-backend`:

```sh
aws iam create-access-key --user-name fcourt-local-s3 --profile tpn12
# AccessKeyId / SecretAccessKey go to AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY in .env (never commit)

# rotate: create a second key, switch .env, then delete the old one
aws iam delete-access-key --user-name fcourt-local-s3 --access-key-id OLD_KEY_ID --profile tpn12
```

### Web stack (fcourt-web on S3 + CloudFront + Route 53)

`envs/shared/web-cdn.tf` serves the web at `https://fcourt.donan.site` (`var.web_domain`), delegated to the Route 53 zone from `web-dns.tf` (add the four `web_zone_name_servers` as NS records at the registrar first: ACM DNS validation, and so `apply`, waits for the delegation).

- Private bucket `fcourt-web-<account_id>` reached only through CloudFront Origin Access Control. ACM certificate in us-east-1 (provider alias), validated through Route 53. Distribution with alias `A`/`AAAA` records, `PriceClass_200` (includes Asia), no WAF, no logging bucket.
- Default behavior: S3 with a CloudFront Function that rewrites extension-less paths to `/index.html` (SPA routes). There are no custom error responses on purpose: they would also swallow API 404s.
- `/api/*`, `/ws-fcourt*`, `/actuator/health`: origin `origin.<web_domain>` over HTTP port 80 (the EKS ALB), `CachingDisabled`, origin request policy `AllViewerExceptHostHeader` (all viewer headers except Host, query strings, cookies; WebSocket upgrade works). The browser stays same-origin, so no CORS.
- IAM role `fcourt-shared-github-web-deploy` for `SBA301-SU26-BRO73/fcourt-web` on `main` (plain and immutable OIDC subject): `s3:ListBucket/GetObject/PutObject/DeleteObject` on the bucket and `cloudfront:CreateInvalidation` on the distribution only.
- Outputs `web_bucket_name`, `web_distribution_id`, `github_web_deploy_role_arn` go to the `fcourt-web` repository variables `WEB_BUCKET`, `WEB_DISTRIBUTION_ID`, `AWS_WEB_DEPLOY_ROLE_ARN`.

The ALB hostname changes on every `down.sh`/`up.sh`, so the distribution never references it. `origin.<web_domain>` is a CNAME maintained by `sh scripts/update-origin-record.sh` (reads the `fcourt-prod/gateway-service` Ingress address, UPSERTs the record; Terraform does not manage it). Run it after Argo CD has synced the gateway (bring-up step 3). Until then `/api/*` returns 502/504 while the static site keeps working.

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

## Scripts

| Script | What it does |
|---|---|
| `sh scripts/up.sh` | Checks files, profile and `TF_VAR_firebase_service_account_json`, exits 1 if the ECR repository or its images (`fcourt/gateway-service`) are missing, then `init` and one `apply` for `envs/prod`. |
| `sh scripts/down.sh` | Pins the kube context to the cluster, stops Argo CD (selfHeal), deletes Ingresses (stripping a stuck finalizer) and waits for the ALB and its security groups to vanish, deletes KafkaTopics (stripping finalizers), the `fcourt-prod`/`data` namespaces and PVCs and waits for EBS volumes, then `terraform destroy` of `envs/prod` only, then read-only leftover inventory. Never touches `envs/shared`. |
| `sh scripts/update-origin-record.sh` | Waits for the `fcourt-prod/gateway-service` Ingress address and UPSERTs `origin.<web domain>` (CloudFront API origin) as a CNAME to it. Run after Argo CD synced the gateway on every bring-up. |
| `sh scripts/check.sh` | `terraform fmt -check` and `init -backend=false` + `validate` for bootstrap, shared and prod. Needs provider download, no AWS access. |

## Cost notes

Prices below are rough estimates from memory (Singapore, 4-hour demo), not quotes. Check the AWS pricing pages.

- Node group is `SPOT`, min/desired/max `2/2/3`, all nodes in a single AZ (`node_subnet_count = 1`, so a replaced Spot node cannot strand an EBS volume in another AZ), 20 GiB gp3 root, IMDSv2. Six interchangeable 2 vCPU/8 GiB types (`t3.large`, `t3a.large`, `m5.large`, `m6i.large`, `m6a.large`, `m7i.large`) improve Spot availability. Spot can be reclaimed at any time; use On-Demand if a demo must not be interrupted. One 8 GiB node is not enough for 12 services, Eureka, the gateway and data.
- `nodes_in_public_subnets = true` puts nodes in public subnets and skips the NAT gateway (about $0.06/h saved). Nodes get public IPs but security groups allow no inbound traffic and the API is limited to `cluster_public_access_cidrs`. Use for short demos only.
- Control-plane logging, VPC flow logs, interface endpoints and KMS secrets encryption are off by default.
- Budget alert (in `envs/shared`, excludes credits and refunds): `monthly_budget_usd = 20`, emails at 5, 10 and 15 USD actual and 100% forecast. Alerts do not stop spending.
- Rough cost while running: EKS control plane ~$0.10/h, one Spot node ~$0.05-0.15/h, ALB ~$0.02-0.03/h. That is roughly $1-2 for a 4-hour demo.

**Shut down after the demo** (`sh scripts/down.sh`). Things that still cost money after destroy if forgotten: leftover EBS volumes (PVCs), ALBs created by Ingress, old state bucket versions, active SNS resources.

Sizing: request memory is about 8 GiB for everything; two 8 GiB nodes is the minimum. If pods stay `Pending` or are `OOMKilled`, check `kubectl top nodes/pods`.

## Bring-up order

1. `bootstrap` (once), then `shared` (once), then push images (CI on merge to `dev`, or manually). `up.sh` refuses to run until `fcourt/gateway-service` has an image. Then prod.
2. `sh scripts/up.sh` runs one `terraform apply` of `envs/prod` (module `push` takes the cluster ARN from `module.eks`, so no `-target` is needed).
3. Follow the `fcourt-gitops` README for Argo CD, secrets and the root app.
4. `sh scripts/down.sh` when done.

## Out of scope

No DNS/Route 53, ACM, WAF, CloudFront, VPN, bastion, Helm releases, Kubernetes namespaces/secrets, SQL migrations, Kafka topics/ACLs, managed databases (RDS, MSK, ElastiCache) or monitoring stack. Those belong to `fcourt-gitops` or later work. The Firebase credential is stored in Terraform state through the SNS platform application, so restrict access to state.
