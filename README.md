# fcourt-infra

Terraform cho hạ tầng AWS của FCourt tại `ap-southeast-1`. Repo này quản lý các tài nguyên nền tảng; `fcourt-backend` build và đẩy image dịch vụ lên ECR, còn `fcourt-gitops` triển khai image và workload lên Kubernetes.

## Cấu trúc

- `modules/ecr`: tạo một ECR repository cho mỗi dịch vụ, bật scan khi push và lifecycle policy.
- `modules/pod-identity`: tra cứu EKS cluster hiện có theo tên rồi tạo association cho service account.
- `modules/push`: SNS Platform Application cho FCM, role ghi delivery log, IAM role cho notification-service, CloudWatch alarm và tùy chọn SQS/DLQ/EventBridge Scheduler.
- `envs/dev`: cấu hình dev; quản lý ECR dùng chung và tài nguyên push dev.
- `envs/prod`: skeleton cấu hình prod, chưa áp dụng. Không quản lý lại các ECR repository dùng chung.
- `scripts/check.sh`: kiểm tra định dạng, init không dùng backend và validate mọi env/module.

## Trước khi khởi tạo

Cần cung cấp:

1. Tên chính xác của EKS cluster đã tồn tại (`eks_cluster_name`). Terraform chỉ đọc cluster bằng data source; repo này không tạo EKS, VPC, RDS hoặc MSK. Các hệ thống đó phải được cấp phát và quản lý ở nơi khác.
2. Firebase service-account JSON có quyền gửi FCM. Truyền toàn bộ nội dung qua secret store của CI hoặc `TF_VAR_firebase_service_account_json`. Không đặt JSON trong Git hay file tfvars. Giá trị nhạy cảm vẫn có thể được ghi trong Terraform state; bảo vệ state bucket, mã hóa, khóa truy cập và quy định rotation.
3. Bucket S3 state đã tạo và được bảo vệ. Sao chép `backend.hcl.example` thành `backend.hcl` trong env tương ứng và điền bucket thật. `key` đã tách riêng dev/prod; xác nhận quy ước state locking với nhóm vận hành.
4. (Tùy chọn) ARN SNS topic có sẵn cho CloudWatch alarm. ARN để trống thì alarm không gửi thông báo.
5. Nếu dùng IRSA thay vì Pod Identity, đặt `identity_mode = "irsa"` và cung cấp `oidc_provider_arn` của cluster; provider OIDC phải tồn tại trong IAM.

Pod Identity là mặc định vì `fcourt-gitops` không gắn IRSA annotation. Dev association dùng namespace `fcourt-dev`, service account `notification-service`; prod mặc định dùng `fcourt-prod` với cùng service account. EKS cần hỗ trợ Pod Identity và Pod Identity Agent cần được cài. Role trust được giới hạn theo account và ARN cluster tra cứu.

## Khởi tạo và xem kế hoạch

Ví dụ cho dev, từ thư mục repo:

```powershell
Copy-Item envs/dev/backend.hcl.example envs/dev/backend.hcl
# Điền bucket state thật vào envs/dev/backend.hcl.
$env:TF_VAR_firebase_service_account_json = Get-Content C:\secure\firebase-service-account.json -Raw
terraform -chdir=envs/dev init -backend-config=backend.hcl
terraform -chdir=envs/dev plan
```

Với prod, dùng `envs/prod/backend.hcl.example`, cấu hình secrets/biến prod riêng và chạy lệnh với `-chdir=envs/prod`. Prod hiện chỉ là skeleton, chưa được áp dụng. Lệnh `plan` kết nối AWS và cần credentials hợp lệ; không dùng AWS profile khác để vượt qua lỗi xác thực.

Để chạy kiểm tra tĩnh không dùng AWS/backend:

```sh
sh scripts/check.sh
```

Script dùng `terraform init -backend=false` và `terraform validate` trên từng env và module. Lệnh init không truy cập backend/AWS, nhưng cần AWS provider đã cache hoặc kết nối tới Terraform Registry. Không thay thế cho kế hoạch thực tế.

## ECR

Module tạo `fcourt/<service>` cho `auth-service`, `subscription-service`, `facility-service`, `reporting-service`, `discovery-service`, `voucher-service`, `slot-hold-engine`, `booking-service`, `payment-service`, `staff-operations-service`, `notification-service` và `pos-retail-service`. Tag image là immutable; scan bật khi push; lifecycle mặc định giữ 30 image có tag và xóa image không tag sau 7 ngày. ECR được quản lý từ state dev để tránh tạo trùng repository giữa môi trường. Backend build/push image; gitops tham chiếu URI ECR.

## IAM và giới hạn xác minh

Quyền của notification-service chỉ gồm các API mobile push cần thiết và bị giới hạn tại region hiện tại. AWS không công bố resource type IAM cho các API mobile endpoint SNS, nên nhóm API này cần `Resource = "*"`; điều đó cũng có nghĩa quyền tạo/xóa endpoint không thể bị ràng buộc theo ARN Platform Application ở IAM. Các queue và schedule group reminder bị giới hạn theo ARN tài nguyên của module, cùng `iam:PassRole` tới đúng Scheduler execution role và đúng service đích. SNS delivery logging chỉ được ghi vào log group `sns/<region>/<account>/*` của tài khoản/khu vực hiện tại. Scheduler execution role chỉ được `sqs:SendMessage` vào queue reminder.

Chưa chạy `plan` với AWS nên chưa xác minh được tên cluster/account thực tế, quyền IAM của caller, khả năng SNS chấp nhận FCM credential, ARN/định dạng metric thực tế, tương thích IAM resource-level với từng API, sự tồn tại của EKS Pod Identity Agent/association prerequisites, hay cấu hình thực tế của bucket/topic. Các giả định và quyết định còn mở:

- Tên bucket state, chính sách khóa/locking và tên cluster được đội vận hành cung cấp.
- ECR retention (30 image có tag, 7 ngày không tag), quy ước tag immutable, alarm threshold mặc định, namespace prod và retention SQS cần được xác nhận vận hành.
- Chưa xác nhận các repository `fcourt-backend` và `fcourt-gitops` đã thống nhất tên URI image, namespace prod, và cơ chế phát hành tag immutable.
- Firebase credential nằm trong state sau khi cấu hình SNS; cần chấp thuận mô hình lưu/rotation secret trước khi triển khai.
- Hạ tầng EKS, VPC, RDS, MSK và các nền tảng hạ tầng dùng chung nằm ngoài phạm vi repo này và chưa được provision bởi cấu hình này.
