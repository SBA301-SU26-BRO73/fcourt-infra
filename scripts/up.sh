#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEV_DIR="$ROOT/envs/dev"

if [ ! -f "$DEV_DIR/backend.hcl" ]; then
  echo "Missing $DEV_DIR/backend.hcl; copy backend.hcl.example and configure the state bucket." >&2
  exit 1
fi
if [ ! -f "$DEV_DIR/terraform.tfvars" ]; then
  echo "Missing $DEV_DIR/terraform.tfvars; copy terraform.tfvars.example and set trusted ARNs, CIDRs, and budget_email." >&2
  exit 1
fi

terraform -chdir="$DEV_DIR" init -backend-config=backend.hcl
terraform -chdir="$DEV_DIR" apply
