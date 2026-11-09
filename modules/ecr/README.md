# ecr

One scanned ECR repository per service with a lifecycle policy for untagged and old tagged images. Tag mutability is configurable (`image_tag_mutability`, default IMMUTABLE; `envs/shared` uses MUTABLE so CI can move the `dev` tag). Used only by `envs/shared`.

## Usage

```hcl
module "ecr" {
  source = "../../modules/ecr"
  # ... required inputs below
}
```

## Inputs

| Name | Description | Required |
|---|---|---|
| `repository_prefix` | Prefix used for ECR repository names. | no |
| `services` | Service names that receive one ECR repository each. | no |
| `tagged_image_count` | Maximum number of tagged images to retain per repository. | no |
| `untagged_image_retention_days` | Age in days after which untagged images expire. | no |
| `tags` | Tags applied to supported resources. | no |

## Outputs

| Name | Description |
|---|---|
| `repository_urls` | Map of service names to ECR repository URLs. |
| `registry_url` | Account ECR registry hostname shared by this environment's repositories. |
| `repository_arns` | Map of service names to ECR repository ARNs. |
