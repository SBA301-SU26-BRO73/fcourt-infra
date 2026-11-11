#!/usr/bin/env sh
# Create the prod environment with a single apply (no -target needed). Usage: sh scripts/up.sh
# Prerequisites: envs/bootstrap applied, envs/shared applied (ECR + CI role), envs/prod/backend.hcl and terraform.tfvars.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROD_DIR="$ROOT/envs/prod"
export AWS_PROFILE=${AWS_PROFILE:-tpn12}
export AWS_REGION=${AWS_REGION:-ap-southeast-1}
export AWS_DEFAULT_REGION=$AWS_REGION

if [ "$AWS_PROFILE" != "tpn12" ]; then
  echo "Refusing to run with AWS_PROFILE=$AWS_PROFILE; use tpn12." >&2
  exit 1
fi
if [ ! -f "$PROD_DIR/backend.hcl" ]; then
  echo "Missing $PROD_DIR/backend.hcl; copy backend.hcl.example and set the state bucket." >&2
  exit 1
fi
if [ ! -f "$PROD_DIR/terraform.tfvars" ]; then
  echo "Missing $PROD_DIR/terraform.tfvars; copy terraform.tfvars.example and set admin ARNs, CIDRs and budget_email." >&2
  exit 1
fi
if [ -z "${TF_VAR_firebase_service_account_json:-}" ]; then
  echo "Set TF_VAR_firebase_service_account_json (Firebase service-account JSON content) first." >&2
  exit 1
fi

# Read-only: images live in the shared root, not in prod.
if ! aws ecr describe-repositories --repository-names fcourt/auth-service >/dev/null 2>&1; then
  echo "WARNING: ECR repository fcourt/auth-service not found. Apply envs/shared and push images first, or pods will ImagePullBackOff." >&2
fi

terraform -chdir="$PROD_DIR" init -backend-config=backend.hcl
terraform -chdir="$PROD_DIR" apply
