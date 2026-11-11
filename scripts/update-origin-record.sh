#!/usr/bin/env sh
# Point the stable CloudFront API origin (origin.<web_domain>) at the current EKS ALB.
# The ALB hostname changes every time the cluster is recreated (down.sh / up.sh), while the CloudFront distribution
# in envs/shared references only the stable name. Run it once the gateway Ingress has an address (Argo CD synced):
#
#   AWS_PROFILE=tpn12 sh scripts/update-origin-record.sh
#
# Idempotent (UPSERT). Needs kubectl access to the cluster and aws access to the Route 53 zone.
set -eu

export AWS_PROFILE=${AWS_PROFILE:-tpn12}
export AWS_REGION=${AWS_REGION:-ap-southeast-1}
export AWS_DEFAULT_REGION=$AWS_REGION
WEB_DOMAIN=${WEB_DOMAIN:-fcourt.donan.site}
ORIGIN_NAME=${ORIGIN_NAME:-origin.$WEB_DOMAIN}
NAMESPACE=${INGRESS_NAMESPACE:-fcourt-prod}
INGRESS=${INGRESS_NAME:-gateway-service}
WAIT_SECONDS=${WAIT_SECONDS:-600}

zone_id=$(aws route53 list-hosted-zones-by-name --dns-name "$WEB_DOMAIN" --max-items 1 \
  --query "HostedZones[?Name=='$WEB_DOMAIN.'].Id | [0]" --output text | sed 's|.*/||')
if [ -z "$zone_id" ] || [ "$zone_id" = "None" ]; then
  echo "Hosted zone $WEB_DOMAIN not found." >&2
  exit 1
fi

elapsed=0
alb=""
while :; do
  alb=$(kubectl -n "$NAMESPACE" get ingress "$INGRESS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$alb" ] && break
  if [ "$elapsed" -ge "$WAIT_SECONDS" ]; then
    echo "Ingress $NAMESPACE/$INGRESS has no address after ${WAIT_SECONDS}s." >&2
    exit 1
  fi
  echo "Waiting for the $INGRESS ingress address..."
  sleep 15
  elapsed=$((elapsed + 15))
done

change=$(printf '{"Comment":"CloudFront API origin -> current ALB","Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"%s","Type":"CNAME","TTL":60,"ResourceRecords":[{"Value":"%s"}]}}]}' "$ORIGIN_NAME" "$alb")
aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch "$change" \
  --query 'ChangeInfo.Status' --output text
echo "$ORIGIN_NAME -> $alb"
