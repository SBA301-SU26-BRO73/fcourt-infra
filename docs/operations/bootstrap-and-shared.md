# Bootstrap and shared root

Moved from the old README.

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

