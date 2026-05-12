#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

jq . protocol/managed-config.schema.json >/dev/null
jq . protocol/managed-config.example.json >/dev/null
bash -n scripts/check.sh
bash -n scripts/download-model.sh
bash -n scripts/install-local-app.sh
bash -n scripts/package-macos-app.sh
bash -n scripts/reset-accessibility.sh
bash -n scripts/verify-app-bundle.sh

swift build --package-path app
swift run --package-path app AunAppConfigCheck
