#!/usr/bin/env sh
# Offline checks: formatting plus init (no backend) and validate for every root module.
# Reusable modules under modules/ are validated through the environments that call them.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
errors=0

echo "==> terraform fmt -check -recursive"
if terraform -chdir="$ROOT" fmt -check -recursive; then
  echo "PASS fmt"
else
  echo "FAIL fmt"
  errors=1
fi

for dir in "$ROOT"/envs/bootstrap "$ROOT"/envs/shared "$ROOT"/envs/prod; do
  [ -d "$dir" ] || continue
  echo "==> $dir"
  if terraform -chdir="$dir" init -backend=false -input=false >/dev/null && terraform -chdir="$dir" validate; then
    echo "PASS validate: $dir"
  else
    echo "FAIL validate: $dir"
    errors=1
  fi
done

echo "==> ECR must live only in envs/shared"
if grep -ls "modules/ecr" "$ROOT"/envs/prod/*.tf >/dev/null 2>&1; then
  echo "FAIL: prod references modules/ecr"
  errors=1
else
  echo "PASS ecr only in shared"
fi

exit "$errors"
