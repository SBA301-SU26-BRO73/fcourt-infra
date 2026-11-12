# Scripts and bring-up order

Moved from the old README.

## Scripts

| Script | What it does |
|---|---|
| `sh scripts/up.sh` | Checks files, profile and `TF_VAR_firebase_service_account_json`, exits 1 if the ECR repository or its images (`fcourt/gateway-service`) are missing, then `init` and one `apply` for `envs/prod`. |
| `sh scripts/down.sh` | Pins the kube context to the cluster, stops Argo CD (selfHeal), deletes Ingresses (stripping a stuck finalizer) and waits for the ALB and its security groups to vanish, deletes KafkaTopics (stripping finalizers), the `fcourt-prod`/`data` namespaces and PVCs and waits for EBS volumes, then `terraform destroy` of `envs/prod` only, then read-only leftover inventory. Never touches `envs/shared`. |
| `sh scripts/update-origin-record.sh` | Waits for the `fcourt-prod/gateway-service` Ingress address and UPSERTs `origin.<web domain>` (CloudFront API origin) as a CNAME to it. Run after Argo CD synced the gateway on every bring-up. |
| `sh scripts/check.sh` | `terraform fmt -check` and `init -backend=false` + `validate` for bootstrap, shared and prod. Needs provider download, no AWS access. |


## Bring-up order

1. `bootstrap` (once), then `shared` (once), then push images (CI on merge to `dev`, or manually). `up.sh` refuses to run until `fcourt/gateway-service` has an image. Then prod.
2. `sh scripts/up.sh` runs one `terraform apply` of `envs/prod` (module `push` takes the cluster ARN from `module.eks`, so no `-target` is needed).
3. Follow the `fcourt-gitops` README for Argo CD, secrets and the root app.
4. `sh scripts/down.sh` when done.

