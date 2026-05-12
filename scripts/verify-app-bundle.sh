#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bundle_path="${AUN_BUNDLE_PATH:-dist/Aun.app}"

[[ -d "$bundle_path/Contents/MacOS" ]]
[[ -x "$bundle_path/Contents/MacOS/Aun" ]]
[[ -f "$bundle_path/Contents/Info.plist" ]]
[[ -f "$bundle_path/Contents/Resources/Aun.icns" ]]
[[ -f "$bundle_path/Contents/Resources/AunMark.png" ]]
[[ -f "$bundle_path/Contents/Resources/managed-config.example.json" ]]

echo "app bundle verification passed: $bundle_path"
