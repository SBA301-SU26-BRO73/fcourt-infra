#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEV_DIR="$ROOT/envs/dev"
AWS_REGION=${AWS_REGION:-ap-southeast-1}
TIMEOUT_SECONDS=${TEARDOWN_TIMEOUT_SECONDS:-600}

echo "Deleting Ingress resources in every namespace..."
kubectl delete ingress --all --all-namespaces --ignore-not-found --wait=true --timeout=5m

echo "Deleting PVCs in every namespace..."
kubectl delete pvc --all --all-namespaces --ignore-not-found --wait=true --timeout=5m

echo "Waiting up to ${TIMEOUT_SECONDS}s for Ingresses and PVCs to disappear..."
elapsed=0
while [ "$elapsed" -lt "$TIMEOUT_SECONDS" ]; do
  remaining=$(kubectl get ingress,pvc --all-namespaces -o name 2>/dev/null || true)
  if [ -z "$remaining" ]; then
    break
  fi
  sleep 10
  elapsed=$((elapsed + 10))
done
remaining=$(kubectl get ingress,pvc --all-namespaces -o name 2>/dev/null || true)
if [ -n "${remaining:-}" ]; then
  echo "Timed out waiting for Ingresses/PVCs to disappear; refusing Terraform destroy." >&2
  printf '%s\n' "$remaining" >&2
  exit 1
fi

terraform -chdir="$DEV_DIR" destroy

echo "Read-only inventory of tagged fcourt leftovers in $AWS_REGION:"
echo "Load balancers:"
aws resourcegroupstaggingapi get-resources --region "$AWS_REGION" --tag-filters Key=Project,Values=fcourt --resource-type-filters elasticloadbalancing:loadbalancer
echo "EBS volumes:"
aws ec2 describe-volumes --region "$AWS_REGION" --filters Name=tag:Project,Values=fcourt --query 'Volumes[].{Id:VolumeId,State:State,AZ:AvailabilityZone,SizeGiB:Size,Tags:Tags}' --output table
echo "Network interfaces:"
aws ec2 describe-network-interfaces --region "$AWS_REGION" --filters Name=tag:Project,Values=fcourt --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Status:Status,Description:Description,Tags:TagSet}' --output table
echo "NAT gateways:"
aws ec2 describe-nat-gateways --region "$AWS_REGION" --filter Name=tag:Project,Values=fcourt --query 'NatGateways[].{Id:NatGatewayId,State:State,VpcId:VpcId,Tags:Tags}' --output table
echo "WARNING: review any listed resources and remove them manually only after confirming ownership and dependencies."
