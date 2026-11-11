# media

S3 bucket for avatars, branch images, review images and sensitive documents (see `fcourt-backend` `docs/storage-s3.md`), plus optional least-privilege Pod Identity roles per service.

- Bucket: ACLs disabled, SSE-S3, TLS-only, multipart cleanup, private prefixes move to STANDARD_IA after 90 days (never expired).
- Public read (bucket policy) only for `public_prefixes` (`avatars/`, `branches/`, `reviews/`). `owner-documents/`, `receipts/` and `refund-proofs/` are reachable only through presigned URLs.
- Service roles (`create_service_roles = true`): `auth-service`, `facility-service`, `discovery-service`, `payment-service`, `booking-service`, trusted by `pods.eks.amazonaws.com` for the given cluster. Bind them with `modules/pod-identity` `extra_associations`.
- Used twice: `envs/prod` (EKS bucket with service roles, `force_destroy = true`) and `envs/shared` (long-lived local docker-compose bucket, `create_service_roles = false`).

## Usage

```hcl
module "media" {
  source           = "../../modules/media"
  bucket_name      = "fcourt-prod-media-123456789012"
  role_name_prefix = "fcourt-prod-media"
  cluster_arn      = module.eks.cluster_arn
  tags             = local.tags
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `bucket_name` | Globally unique bucket name. | yes |
| `create_service_roles` | Create the per-service Pod Identity roles (default true). | no |
| `cluster_arn` | EKS cluster ARN for the trust policy; required when `create_service_roles` is true. | conditional |
| `role_name_prefix` | Prefix for the per-service roles; required when `create_service_roles` is true. | conditional |
| `force_destroy` | Delete all objects on destroy (default false). | no |
| `public_prefixes` | Prefixes readable anonymously over HTTPS. | no |
| `private_ia_prefixes` | Private prefixes moved to STANDARD_IA after 90 days. | no |
| `tags` | Common resource tags. | no |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Bucket name (`STORAGE_S3_BUCKET`). |
| `bucket_arn` | Bucket ARN. |
| `region` | Bucket region (`STORAGE_S3_REGION`). |
| `public_base_url` | `https://<bucket>.s3.<region>.amazonaws.com` (`STORAGE_PUBLIC_BASE_URL`). |
| `service_role_arns` | Role ARN by service account name; empty when `create_service_roles` is false. |
