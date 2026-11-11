#!/usr/bin/env sh
# Tear down the prod environment. Usage: sh scripts/down.sh
# Order matters: stop Argo CD self-heal, delete Ingresses and wait for the ALB to vanish, delete workloads and PVCs
# (EBS volumes), then terraform destroy for envs/prod ONLY. envs/shared (ECR, CI role) and envs/bootstrap are never touched.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROD_DIR="$ROOT/envs/prod"
export AWS_PROFILE=${AWS_PROFILE:-tpn12}
export AWS_REGION=${AWS_REGION:-ap-southeast-1}
export AWS_DEFAULT_REGION=$AWS_REGION
CLUSTER=${CLUSTER_NAME:-fcourt-prod}
TIMEOUT_SECONDS=${TEARDOWN_TIMEOUT_SECONDS:-600}

if [ "$AWS_PROFILE" != "tpn12" ]; then
  echo "Refusing to run with AWS_PROFILE=$AWS_PROFILE; use tpn12." >&2
  exit 1
fi

# wait_until_empty <description> <command printing leftovers>
wait_until_empty() {
  desc=$1
  shift
  elapsed=0
  while [ "$elapsed" -lt "$TIMEOUT_SECONDS" ]; do
    left=$("$@" 2>/dev/null || true)
    [ -z "$left" ] && return 0
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo "Timed out waiting for $desc to disappear; refusing terraform destroy." >&2
  printf '%s\n' "$left" >&2
  exit 1
}

alb_names() { aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text | tr '\t' '\n' | grep '^k8s-' || true; }
lbc_sgs() { aws ec2 describe-security-groups --filters "Name=tag:elbv2.k8s.aws/cluster,Values=$CLUSTER" --query 'SecurityGroups[].GroupId' --output text | tr '\t' '\n'; }
# Volumes created by the EBS CSI driver carry ebs.csi.aws.com/cluster=true (plus Project=fcourt via extraVolumeTags).
orphan_volumes() {
  { aws ec2 describe-volumes --filters Name=tag:Project,Values=fcourt Name=status,Values=available --query 'Volumes[].VolumeId' --output text
    aws ec2 describe-volumes --filters Name=tag:ebs.csi.aws.com/cluster,Values=true Name=status,Values=available --query 'Volumes[].VolumeId' --output text
  } | tr '\t' '\n' | sort -u | grep -v '^$' || true
}

# Pin the kube context to this cluster so kubectl can never act on another one.
aws eks update-kubeconfig --name "$CLUSTER" --region "$AWS_REGION" --alias "$CLUSTER" >/dev/null
KCTX=$CLUSTER
kubectl() { command kubectl --context "$KCTX" "$@"; }

echo "Step 1/5: stop Argo CD so it cannot recreate what we delete (selfHeal)..."
if kubectl get ns argocd >/dev/null 2>&1; then
  kubectl -n argocd delete applicationset --all --ignore-not-found --wait=false || true
  kubectl -n argocd delete application --all --cascade=orphan --ignore-not-found --wait=false || true
  # Strip finalizers in case an Application is stuck in deletion.
  for app in $(kubectl -n argocd get application -o name 2>/dev/null || true); do
    kubectl -n argocd patch "$app" --type merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
  kubectl -n argocd scale statefulset argocd-application-controller --replicas=0 || true
  kubectl -n argocd scale deploy argocd-applicationset-controller argocd-repo-server argocd-server --replicas=0 || true
else
  echo "No argocd namespace; skipping."
fi

echo "Step 2/5: delete Ingresses (the AWS Load Balancer Controller must still run) and wait for the ALB..."
if ! kubectl delete ingress --all --all-namespaces --ignore-not-found --wait=true --timeout=5m; then
  echo "Ingress deletion timed out; stripping Ingress finalizers and continuing..." >&2
  kubectl get ingress --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null |
    while read -r ns name; do
      [ -n "$name" ] && kubectl -n "$ns" patch ingress "$name" --type=merge -p '{"metadata":{"finalizers":null}}' || true
    done
fi
wait_until_empty "ALB (k8s-*)" alb_names
wait_until_empty "controller security groups" lbc_sgs

echo "Step 3/5: delete workloads and PVCs (reclaimPolicy Delete removes the EBS volumes)..."
# Strimzi KafkaTopics block namespace deletion once the operator is gone: delete them first, then strip finalizers.
kubectl -n data delete kafkatopic --all --timeout=2m || true
kubectl -n data get kafkatopic -o name | xargs -r -I{} kubectl --context "$KCTX" -n data patch {} --type=merge -p '{"metadata":{"finalizers":null}}' || true
kubectl delete namespace fcourt-prod data --ignore-not-found --wait=true --timeout=10m
kubectl delete pvc --all --all-namespaces --ignore-not-found --wait=true --timeout=5m
wait_until_empty "unattached fcourt EBS volumes" orphan_volumes

echo "Step 4/5: terraform destroy (envs/prod only; ECR in envs/shared is untouched)..."
terraform -chdir="$PROD_DIR" init -backend-config=backend.hcl
terraform -chdir="$PROD_DIR" destroy

echo "Step 5/5: read-only inventory of leftovers in $AWS_REGION (each list should be empty):"
echo "EKS clusters:";        aws eks list-clusters --output text
echo "Load balancers:";      aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text
echo "EBS volumes:";         aws ec2 describe-volumes --filters Name=tag:Project,Values=fcourt --query 'Volumes[].{Id:VolumeId,State:State,Size:Size}' --output table
echo "Network interfaces:";  aws ec2 describe-network-interfaces --filters Name=tag:Project,Values=fcourt --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Status:Status,Description:Description}' --output table
echo "NAT gateways:";        aws ec2 describe-nat-gateways --filter Name=state,Values=available,pending --query 'NatGateways[].NatGatewayId' --output text
echo "Elastic IPs:";         aws ec2 describe-addresses --query 'Addresses[].PublicIp' --output text
echo "WARNING: review anything listed and remove it only after confirming ownership and dependencies."
