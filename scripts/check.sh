#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
errors=0

# The module glob includes modules/budget and all reusable infrastructure modules.
for dir in "$ROOT"/envs/* "$ROOT"/modules/*; do
  [ -d "$dir" ] || continue
  echo "==> $dir"
  if terraform -chdir="$dir" fmt -check -recursive; then
    echo "PASS fmt: $dir"
  else
    echo "FAIL fmt: $dir"
    errors=1
  fi
  if terraform -chdir="$dir" init -backend=false -input=false; then
    echo "PASS init: $dir"
  else
    echo "FAIL init: $dir"
    errors=1
  fi
  if terraform -chdir="$dir" validate; then
    echo "PASS validate: $dir"
  else
    echo "FAIL validate: $dir"
    errors=1
  fi
done

exit "$errors"
