#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

configuration="${AUN_SWIFT_CONFIGURATION:-release}"
bundle_name="${AUN_BUNDLE_NAME:-Aun}"
bundle_id="${AUN_BUNDLE_ID:-dev.aun.Aun}"
dist_dir="$repo_root/dist"
bundle_dir="$dist_dir/$bundle_name.app"
contents_dir="$bundle_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

swift build --package-path app -c "$configuration"

binary_path="$repo_root/app/.build/$configuration/AunApp"
if [[ ! -x "$binary_path" ]]; then
  echo "expected Swift executable at $binary_path" >&2
  exit 1
fi

rm -rf "$bundle_dir"
mkdir -p "$macos_dir" "$resources_dir"
cp "$binary_path" "$macos_dir/$bundle_name"
cp protocol/managed-config.example.json "$resources_dir/managed-config.example.json"
cp app/Aun.entitlements "$resources_dir/Aun.entitlements"
cp app/Resources/Aun.icns "$resources_dir/Aun.icns"
cp assets/brand/aun-mark.png "$resources_dir/AunMark.png"
cp assets/brand/StatusBarIcon.png "$resources_dir/StatusBarIcon.png"
cp assets/brand/StatusBarIcon@2x.png "$resources_dir/StatusBarIcon@2x.png"

cat >"$contents_dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$bundle_name</string>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleName</key>
  <string>$bundle_name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>Aun.icns</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright Aun contributors.</string>
</dict>
</plist>
PLIST

scripts/verify-app-bundle.sh
echo "created $bundle_dir"
