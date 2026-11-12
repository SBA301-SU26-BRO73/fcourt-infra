# fcourt-infra

Terraform cho phần AWS của FCourt (hệ thống đặt sân: các microservice Spring Boot chạy trên Kafka), region `ap-southeast-1`. Repo tạo VPC, cluster EKS, các ECR repository, S3 bucket, stack web CloudFront + Route 53 + ACM, SNS push, các IAM role Pod Identity và budget chi phí. PostgreSQL, Kafka và Redis chạy bên trong cluster và do `fcourt-gitops` quản lý, không phải Terraform.

Chỉ có một môi trường, `prod`. Cluster được thiết kế rẻ (hai node Spot trong một AZ, mặc định không có NAT, EKS 1.35), được dựng lên để demo rồi destroy ngay sau đó.

## Vai trò trong hệ thống FCourt

| Repo | Trách nhiệm |
|---|---|
| **fcourt-infra** (repo này) | Hạ tầng AWS (Terraform) |
| `fcourt-gitops` | Argo CD app và manifest chạy trên cluster EKS được tạo ở đây; dùng output `gitops_values` |
| `fcourt-backend` | Các microservice; CI của nó push image lên các ECR repository tạo ở đây qua một GitHub OIDC role |
| `fcourt-web` | Web frontend được deploy lên S3 bucket và CloudFront distribution tạo ở đây (https://fcourt.donan.site) |
| `fcourt-flutter` | Ứng dụng Android gọi API qua cùng domain |

## Công nghệ

Terraform `>= 1.10.0, < 2.0.0` (S3 native state locking), provider `hashicorp/aws ~> 5.80`, AWS CLI. Remote state nằm trong một S3 bucket do `envs/bootstrap` tạo.

## Cấu trúc dự án

```text
fcourt-infra/
|- envs/
|  |- bootstrap/   # S3 bucket chứa state (local state, apply một lần)
|  |- shared/      # tồn tại lâu dài: ECR, GitHub OIDC + role push/deploy, budget, media bucket local,
|  |               #   stack web (S3, CloudFront, Route 53, ACM)
|  |- prod/        # VPC, EKS, Pod Identity, SNS push, media bucket (destroy sau mỗi lần demo)
|- modules/        # network, eks, pod-identity, ecr, media, push, budget (mỗi module có README.md)
|- scripts/        # up.sh, down.sh, check.sh, update-origin-record.sh
|- docs/           # xem docs/README.md
```

Chi tiết và quy ước: [docs/architecture/layout-and-conventions.md](docs/architecture/layout-and-conventions.md).

## Yêu cầu

- Terraform `>= 1.10.0`, AWS CLI, `kubectl` (dùng bởi `down.sh` và script cập nhật origin record).
- Một AWS CLI profile có quyền cấp admin trên account (`export AWS_PROFILE=<profile>`).
- File JSON service account của Firebase cho FCM push (truyền qua biến môi trường, không bao giờ đặt trong tfvars).

## Quy trình làm việc

Thứ tự: bootstrap, shared, push image (CI hoặc thủ công), prod.

```sh
export AWS_PROFILE=<profile>

# 1. một lần: bucket chứa state
terraform -chdir=envs/bootstrap init
terraform -chdir=envs/bootstrap apply -var="state_bucket_name=<unique-bucket-name>"

# 2. một lần: các tài nguyên shared tồn tại lâu dài
cp envs/shared/backend.hcl.example envs/shared/backend.hcl
cp envs/shared/terraform.tfvars.example envs/shared/terraform.tfvars
terraform -chdir=envs/shared init -backend-config=backend.hcl
terraform -chdir=envs/shared apply

# 3. mỗi lần demo: prod (cluster và data plane)
cp envs/prod/backend.hcl.example envs/prod/backend.hcl
cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars
export TF_VAR_firebase_service_account_json="$(cat /path/to/firebase-service-account.json)"
sh scripts/up.sh          # init + một lần apply envs/prod
sh scripts/down.sh        # dừng Argo CD, xóa ALB/PVC, chỉ destroy envs/prod
```

Sau `up.sh`, tiếp tục theo README của `fcourt-gitops` (Argo CD, secret, root app), rồi chạy `sh scripts/update-origin-record.sh` một lần khi Ingress của gateway đã có địa chỉ. Các bước đầy đủ: [docs/operations](docs/operations/).

| Script | Mục đích |
|---|---|
| `scripts/up.sh` | Kiểm tra điều kiện (gồm việc `fcourt/gateway-service` đã có image trong ECR), rồi `init` và `apply` `envs/prod` |
| `scripts/down.sh` | Gỡ các Argo CD app, Ingress/ALB, PVC, rồi `terraform destroy` `envs/prod`; không bao giờ đụng tới `envs/shared` |
| `scripts/update-origin-record.sh` | Trỏ `origin.<web domain>` (API origin của CloudFront) tới ALB hiện tại |
| `scripts/check.sh` | `terraform fmt -check` và `validate` offline cho bootstrap, shared, prod |

## Cấu hình

Mỗi root có `terraform.tfvars.example` và `backend.hcl.example`; các file thật `terraform.tfvars`, `backend.hcl`, state và plan bị git-ignore. Các input chính của `envs/prod`:

| Biến | Ý nghĩa |
|---|---|
| `aws_region` | Region |
| `vpc_cidr` | CIDR của VPC; các subnet được suy ra từ đây |
| `cluster_version`, `eks_instance_types`, `eks_capacity_type` (`SPOT`/`ON_DEMAND`), `eks_min_size`, `eks_desired_size`, `eks_max_size`, `eks_root_volume_size` | Kích thước cluster và node group |
| `cluster_public_access_cidrs` | Bắt buộc. Các CIDR được phép truy cập Kubernetes API public (dùng IP client của bạn dạng `/32`). `0.0.0.0/0` bị validation từ chối. Cập nhật khi IP của bạn đổi, nếu không `kubectl` sẽ bị timeout. |
| `admin_principal_arns` | Bắt buộc. Các IAM principal được cấp quyền cluster-admin |
| `firebase_service_account_json` | Sensitive; đặt qua `TF_VAR_firebase_service_account_json` |
| `nodes_in_public_subnets` | `true` bỏ qua NAT gateway (chỉ dùng cho demo ngắn) |
| `enable_flow_logs`, `enable_interface_endpoints`, `enable_secrets_encryption`, `eks_cluster_log_types` | Các tính năng bổ sung tùy chọn, mặc định tắt để tiết kiệm chi phí |

Không bao giờ commit secret, file state hay tfvars thật. Các output đáng chú ý: `gitops_values` từ `envs/prod` (được `fcourt-gitops/scripts/apply-terraform-outputs.sh` sử dụng), và từ `envs/shared` là các role ARN và giá trị web cần điền vào GitHub repository variables của `fcourt-backend` (`AWS_ECR_PUSH_ROLE_ARN`) và `fcourt-web` (`WEB_BUCKET`, `WEB_DISTRIBUTION_ID`, `AWS_WEB_DEPLOY_ROLE_ARN`).

## CI/CD và triển khai

- Repo này không có CI workflow. Chạy `sh scripts/check.sh` trước mỗi PR (fmt và validate, không cần quyền truy cập AWS).
- Hạ tầng được apply thủ công từ máy cá nhân bằng các lệnh ở trên; hãy xem `terraform plan` trước khi `apply`.
- Các repo khác deploy qua OIDC role được tạo trong `envs/shared`: `fcourt-backend` push image lên ECR, `fcourt-web` sync lên S3 và invalidate CloudFront.
- Tắt hạ tầng sau mỗi lần demo (`sh scripts/down.sh`); EBS volume và ALB còn sót sẽ tiếp tục tốn tiền. Ghi chú chi phí: [docs/operations/cost-notes.md](docs/operations/cost-notes.md).

## Kiểm thử

`sh scripts/check.sh` chạy `terraform fmt -check -recursive` và `init -backend=false` cùng `validate` cho mọi root. Cần tải provider nhưng không cần AWS credentials. Dùng `terraform plan` để xem diff thực tế.

## Đóng góp

- Tạo branch từ `main` với prefix như `feat/`, `fix/`, `docs/`, `chore/`; mở PR vào `main`.
- Commit message và tiêu đề PR viết bằng tiếng Anh (`type(scope): message`). Phần body có thể viết bằng tiếng Việt.
- Giữ nguyên các quy ước: `local.tags` trên mọi root, pin phiên bản provider, có description và validation cho input.
- Không commit `*.tfstate`, `*.tfvars`, `backend.hcl`, plan hay credentials.
