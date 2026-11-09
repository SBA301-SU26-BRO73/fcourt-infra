#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
errors=0

for base in "$ROOT/envs" "$ROOT/modules"; do
  for dir in "$base"/*; do
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
done

exit "$errors"
