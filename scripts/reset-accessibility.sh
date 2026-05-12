#!/usr/bin/env bash
set -euo pipefail

bundle_id="${AUN_BUNDLE_ID:-dev.aun.Aun}"

if ! command -v tccutil >/dev/null 2>&1; then
  echo "tccutil not found" >&2
  exit 1
fi

if tccutil reset Accessibility "$bundle_id"; then
  echo "reset Accessibility permission for $bundle_id"
  echo "Grant Aun again in System Settings > Privacy & Security > Accessibility."
else
  echo "failed to reset Accessibility permission for $bundle_id" >&2
  exit 1
fi
