# fcourt-infra

Terraform cho FCourt trên AWS tại `ap-southeast-1`. Repo hiện tạo VPC, EKS, managed node group, IAM/Pod Identity, ECR và notification resources. `envs/prod` vẫn cấu hình RDS, MSK và ElastiCache Redis; dev dùng PostgreSQL, Kafka và Redis chạy trong Kubernetes do repo `fcourt-gitops` quản lý. Các module managed service vẫn được giữ ở `modules/` để dùng lại cho prod hoặc môi trường khác.

Firebase service-account JSON chỉ nhận qua biến nhạy cảm từ secret store của CI hoặc biến môi trường, không lưu trong Git/tfvars. Credential Firebase có thể nằm trong Terraform state qua SNS platform application; quyền state phải được giới hạn.

## Kiến trúc

```text
envs/bootstrap ──> S3 state bucket (versioning, SSE, public access block, S3 lockfile)
                         │ backend config (dev/prod state key riêng)
                         ▼
VPC ap-southeast-1 (3 AZ)
├── Public subnets: Internet Gateway, ALB subnet tags, NAT nếu dùng node private
├── Private subnets: mặc định cho EKS; S3 gateway endpoint
├── EKS: public API giới hạn CIDR + private API, managed Spot node group ở dev
│   ├── vpc-cni, coredns, kube-proxy, Pod Identity Agent, EBS CSI add-ons
│   └── Pod Identity: ALB Controller, External Secrets, EBS CSI, notification-service
├── Dev: PostgreSQL, Kafka, Redis trong cluster (fcourt-gitops)
├── Prod: RDS PostgreSQL, MSK Serverless, ElastiCache Redis
├── ECR repositories (per environment)
└── SNS/CloudWatch và SQS reminder resources tùy chọn (modules/push)
```

Dev mặc định trong `terraform.tfvars.example` đặt node lên public subnets, gán public IP và bỏ NAT để giảm chi phí. Biến `nodes_in_public_subnets` trong `envs/dev/variables.tf` có default `false`; khi false, node nằm private và một NAT gateway được tạo. Node public nhận địa chỉ IPv4 công khai và có đường ra Internet trực tiếp, tăng bề mặt phơi nhiễm và rủi ro nếu cấu hình sai. Security groups của node vẫn không mở inbound Internet; API Kubernetes vẫn giới hạn bởi `cluster_public_access_cidrs`. Chỉ dùng chế độ public node cho demo ngắn, không dùng cho prod.

## Cấu trúc

- `envs/bootstrap`: tạo bucket state; khởi tạo local một lần.
- `modules/network`, `eks`, `budget`: VPC, EKS và AWS Budget.
- `modules/rds`, `msk`, `redis`: managed data services được giữ cho prod/tương lai; dev không gọi các module này.
- `modules/workload-identity`: role cho AWS Load Balancer Controller và External Secrets Operator.
- `modules/pod-identity`: association notification-service.
- `modules/ecr`, `push`: registry và notification push.
- `envs/dev`, `envs/prod`: cấu hình ghép hạ tầng. Prod giữ nguyên managed services.

## Dựng và tắt cho demo

Trước tiên cần AWS account/role hợp lệ tại Singapore, Terraform `>= 1.10.0`, AWS CLI, `kubectl`, quyền EKS admin, và một bucket S3 duy nhất cho state. Không đổi AWS profile để né lỗi credential. Khởi tạo bucket state một lần:

```sh
terraform -chdir=envs/bootstrap init
terraform -chdir=envs/bootstrap apply -var='state_bucket_name=fcourt-terraform-state-ACCOUNT-UNIQUE'
```

Sao chép `envs/dev/backend.hcl.example` thành `envs/dev/backend.hcl` và điền bucket. Sao chép `envs/dev/terraform.tfvars.example` thành `envs/dev/terraform.tfvars`; điền account ID trong admin ARN, CIDR IP tin cậy, và email nhận ngân sách. Giữ `nodes_in_public_subnets = true` để dùng cấu hình demo rẻ nhất; nếu muốn node private, đổi thành `false` (NAT sẽ được tạo). Inject Firebase JSON qua `TF_VAR_firebase_service_account_json` từ secret store. Backend dùng `use_lockfile = true` của Terraform `>= 1.10.0`; đừng commit backend, tfvars thật, state hoặc credential.

Dựng:

```sh
sh scripts/up.sh
```

Sau khi EKS sẵn sàng, cấu hình kubeconfig, deploy workload từ `fcourt-gitops`, chạy demo rồi luôn tắt ngay. `down.sh` xóa Ingress và PVC trong mọi namespace, chờ chúng biến mất, chạy Terraform destroy dev, rồi chỉ liệt kê tài nguyên còn sót. Script không xóa thủ công tài nguyên AWS.

```sh
sh scripts/down.sh
```

Lệnh thủ công tương đương, theo đúng thứ tự:

```sh
set -e
kubectl delete ingress --all --all-namespaces --ignore-not-found --wait=true --timeout=5m
kubectl delete pvc --all --all-namespaces --ignore-not-found --wait=true --timeout=5m
# Chờ tối đa 10 phút, sau đó dừng nếu Ingress hoặc PVC vẫn còn.
deadline=$(( $(date +%s) + 600 )); while [ "$(date +%s)" -lt "$deadline" ] && [ -n "$(kubectl get ingress,pvc -A -o name 2>/dev/null)" ]; do sleep 10; done
test -z "$(kubectl get ingress,pvc -A -o name 2>/dev/null)"
terraform -chdir=envs/dev init -backend-config=backend.hcl
terraform -chdir=envs/dev destroy
aws resourcegroupstaggingapi get-resources --region ap-southeast-1 --tag-filters Key=Project,Values=fcourt --resource-type-filters elasticloadbalancing:loadbalancer
aws ec2 describe-volumes --region ap-southeast-1 --filters Name=tag:Project,Values=fcourt --output table
aws ec2 describe-network-interfaces --region ap-southeast-1 --filters Name=tag:Project,Values=fcourt --output table
aws ec2 describe-nat-gateways --region ap-southeast-1 --filter Name=tag:Project,Values=fcourt --output table
```

Pastikan `kubectl get ingress,pvc -A` kosong sebelum destroy. Daftar AWS di atas read-only dan perlu diperiksa manual; leftover ALB/ENI bisa menahan penghapusan VPC. State bucket bootstrap sengaja `prevent_destroy`, tidak dihapus saat dev destroy.

## Node sizing dev

Node group dùng `SPOT`, min/desired/max `1/1/2`, root gp3 mã hóa 20 GiB và bắt buộc IMDSv2. Bốn loại mặc định `t3a.xlarge`, `t3.xlarge`, `m5a.xlarge`, `m5.xlarge` đa dạng hóa Spot trong cùng lớp 4 vCPU/16 GiB. Khi đổi `eks_instance_types`, nên chọn các loại có cùng dung lượng; `eks_capacity_type`, `eks_min_size`, `eks_desired_size`, `eks_max_size` và `eks_root_volume_size` cũng là biến cấu hình.

Kích thước một node cho khoảng 12 service Spring Boot cùng PostgreSQL, Kafka và Redis chỉ là ước tính ban đầu, chưa được đo với workload FCourt. Thiếu bộ nhớ/tài nguyên có thể làm pod ở trạng thái `Pending` hoặc container bị `OOMKilled`. Kiểm tra bằng `kubectl describe pod` và `kubectl top nodes/pods`; tăng `eks_instance_types` lên lớp 8 vCPU/32 GiB hoặc đặt min/desired là 2 và max là 2 (vẫn đa dạng loại cùng dung lượng), sau đó chạy `terraform apply` khi môi trường đang hoạt động.

Với chế độ VPC CNI tiêu chuẩn, không bật prefix delegation, lớp instance đã chọn giới hạn khoảng 58 pod mỗi node (công thức tiêu chuẩn: 4 ENI × 15 địa chỉ IPv4 mỗi ENI, trừ địa chỉ node và cộng phần dành cho kubelet). Số lượng này đủ cho 12 service, các pod dữ liệu và add-on hệ thống; CPU/bộ nhớ có thể là giới hạn thực tế trước. Số pod dùng được có thể thấp hơn do DaemonSet và cấu hình CNI. AWS mô tả cách tính max-pods trong tài liệu [EKS AMI](https://github.com/awslabs/amazon-eks-ami) và chức năng CNI trong [EKS VPC CNI](https://docs.aws.amazon.com/eks/latest/best-practices/vpc-cni.html).

AWS có thể thu hồi Spot khi cần dung lượng; không nên giả định một node Spot sẽ luôn sẵn sàng suốt buổi demo. Việc node bị gián đoạn có thể khiến service ngừng hoạt động cho đến khi tìm được dung lượng thay thế. Với demo cần hoạt động liên tục, hãy cân nhắc On-Demand hoặc hai node ở các AZ khác nhau với chi phí cao hơn.

## Chi phí dev (ước tính, không phải báo giá)

Tất cả mức giá dưới đây là ước tính dựa trên ghi nhớ về giá AWS công khai, chưa được kiểm tra hoặc tra cứu bằng calculator. Giả định region Singapore và thời gian demo 4 giờ; chưa gồm VAT, truyền dữ liệu, lượng request/LCU lớn, hạn mức miễn phí hoặc biến động giá Spot.

| Hạng mục dev | Ước tính USD/giờ | Ước tính demo 4 giờ | Ghi chú |
|---|---:|---:|---|
| EKS control plane | ~$0.10/giờ (ước tính theo ghi nhớ, chưa kiểm tra) | ~$0.40 (ước tính theo ghi nhớ, chưa kiểm tra) | Tính phí trong thời gian cluster hoạt động |
| 1 node Spot lớp xlarge | ~$0.05–0.15/giờ (ước tính theo ghi nhớ, chưa kiểm tra) | ~$0.20–0.60 (ước tính theo ghi nhớ, chưa kiểm tra) | Giá node và IPv4 công khai (ước tính ~$0.005/giờ, chưa kiểm tra) thay đổi; Spot có thể bị thu hồi |
| NAT gateway | ~$0/giờ khi demo dùng node public; ~$0.06/giờ nếu node private (ước tính theo ghi nhớ, chưa kiểm tra), chưa gồm dữ liệu | ~$0 hoặc ~$0.24 + dữ liệu (ước tính theo ghi nhớ, chưa kiểm tra) | Chỉ tạo một NAT mặc định cho node private |
| EBS node gp3 20 GiB | ~$0.0027/giờ (ước tính theo ghi nhớ, chưa kiểm tra) | ~$0.011 (ước tính theo ghi nhớ, chưa kiểm tra) | Root volume bị xóa cùng instance; PVC EBS còn sót vẫn tính phí |
| ALB do Ingress tạo | ~$0.02–0.03/giờ cơ bản (ước tính theo ghi nhớ, chưa kiểm tra), chưa gồm LCU | ~$0.08–0.12 cơ bản (ước tính theo ghi nhớ, chưa kiểm tra), chưa gồm LCU | Tùy số Ingress và lưu lượng |
| CloudWatch control-plane logs | ~$0/giờ theo mặc định vì tắt log (ước tính theo ghi nhớ, chưa kiểm tra) | ~$0 mặc định (ước tính theo ghi nhớ, chưa kiểm tra) | Khi bật sẽ tính phí ingest/lưu trữ; retention EKS là 3 ngày |

Sau `terraform destroy`, các khoản sau vẫn có thể phát sinh nếu bị bỏ quên: EBS volume/PVC còn sót, ALB do Ingress tạo, dung lượng lưu ảnh ECR, bucket S3 state và các phiên bản cũ, cùng tài nguyên SNS hoặc phí gửi thông báo khi còn hoạt động. Script cũng kiểm tra NAT/ENI. AWS Budget mặc định $20 mỗi tháng gửi email ở mức thực tế 50%, 100% và dự báo 100%; cảnh báo không chặn chi tiêu và có thể đến trễ.

## Konfigurasi prod dan managed data services

`envs/prod` vẫn tạo RDS PostgreSQL, MSK Serverless và Redis OSS trên ElastiCache; cấu hình prod không bị thay đổi bởi các tối ưu dev. Các module managed service vẫn được giữ để tái sử dụng sau này. Với dev, hãy tạo PostgreSQL/Kafka/Redis và StorageClass trong Kubernetes từ repo `fcourt-gitops`.

Mặc định prod có ba NAT gateway, tối thiểu ba worker, RDS/Redis Multi-AZ và VPC Flow Logs. Hãy xem xét plan, chi phí, tính sẵn sàng và backup trước khi triển khai prod. `cluster_public_access_cidrs` phải là CIDR client đáng tin cậy, không dùng `0.0.0.0/0`; `admin_principal_arns` phải chứa đúng admin role ARN.

Log Kubernetes API ở dev mặc định bị tắt; nếu cần, đặt `eks_cluster_log_types` thành `["audit"]` hoặc `["api"]`, với thời gian lưu CloudWatch mặc định 3 ngày. `enable_secrets_encryption` mặc định là false ở dev để tránh tạo KMS key; hãy bật nếu yêu cầu bảo mật cần. Interface endpoint mặc định bị tắt; S3 Gateway endpoint luôn được tạo. Flow Logs cũng tắt ở dev. Node private vẫn dùng một NAT Gateway.

## Kiểm tra

```sh
terraform fmt -recursive
sh scripts/check.sh
```

`scripts/check.sh` kiểm tra format và chạy init/validate cho toàn bộ env/module, bao gồm `modules/budget`; init cần provider cache hoặc kết nối Terraform Registry. Trong lượt công việc này chỉ chạy lệnh format. Không chạy `terraform init` hoặc `terraform validate` vì không thể tải provider. Không chạy `plan`/`apply` với credential không hợp lệ.

## Phạm vi chưa bao gồm

- Repo không tạo DNS/Route 53, ACM, WAF, CloudFront, VPN, bastion, Helm release, CRD, Kubernetes namespace/secret, SQL migration, DB user theo service, Kafka topic/ACL hoặc monitoring stack.
- State bucket bootstrap riêng biệt và được giữ lại sau demo; chỉ xóa bằng quy trình riêng khi không còn cần state.
- `modules/push` lưu Firebase credential trong Terraform state thông qua SNS platform application. Bảo vệ state bucket và xoay credential theo quy trình vận hành.
- Các phiên bản/đối số cần đối chiếu khi provider sẵn sàng: AWS provider `~> 5.80`, Kubernetes/EKS `1.34`, Redis engine `7.1`, schema `time_unit`/notification của AWS Budgets và khả năng cung cấp Spot của các họ instance trong region. Chưa chạy init/validate nên chưa xác nhận tương thích schema.
