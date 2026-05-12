#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bundle_name="${AUN_BUNDLE_NAME:-Aun}"
source_bundle="${AUN_BUNDLE_PATH:-dist/$bundle_name.app}"
install_dir="${AUN_INSTALL_DIR:-$HOME/Applications}"
install_path="$install_dir/$bundle_name.app"
support_dir="$HOME/Library/Application Support/Aun"
managed_config_path="$support_dir/managed-config.json"
model_path="${AUN_MODEL_PATH:-$repo_root/models/gemma-4-E4B-it-Q4_K_M.gguf}"
prompt_cache="${AUN_PROMPT_CACHE:-$repo_root/models/gemma-4-E4B-it.prompt-cache}"
llama_cli="${LLAMA_CLI:-}"
codesign_identity="${AUN_CODESIGN_IDENTITY:-}"

if [[ -z "$llama_cli" ]] && command -v llama-completion >/dev/null 2>&1; then
  llama_cli="$(command -v llama-completion)"
fi

if [[ -z "$codesign_identity" ]] && command -v security >/dev/null 2>&1; then
  codesign_identity="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | awk -F '"' '/"Aun Local Development"|Apple Development|Developer ID Application/ { print $2; exit }'
  )"
fi

if [[ -z "$codesign_identity" ]]; then
  codesign_identity="-"
fi

scripts/package-macos-app.sh

if pgrep -x "$bundle_name" >/dev/null 2>&1; then
  pkill -x "$bundle_name" || true
  sleep 0.5
fi

mkdir -p "$install_dir" "$support_dir"
rm -rf "$install_path"
ditto "$source_bundle" "$install_path"
xattr -dr com.apple.quarantine "$install_path" 2>/dev/null || true
codesign --force --deep --sign "$codesign_identity" --entitlements app/Aun.entitlements "$install_path" >/dev/null

if [[ -n "$llama_cli" && -f "$model_path" ]]; then
  jq -n \
    --arg llama_cli "$llama_cli" \
    --arg model_path "$model_path" \
    --arg prompt_cache "$prompt_cache" \
    '{
      inference: {
        llama_cli: $llama_cli,
        model_path: $model_path,
        prompt_cache: $prompt_cache,
        context_size: 4096,
        max_tokens: 24,
        temperature: 0.2,
        gpu_layers: 99
      },
      privacy: {
        allow_network_inference: false,
        log_typed_content: false
      },
      policy: {
        idle_debounce_ms: 120,
        min_context_chars: 1,
        max_typing_speed_cps: 8
      }
    }' >"$managed_config_path"
elif [[ -n "$llama_cli" ]]; then
  echo "install warning: model not found at $model_path; local LLM generation disabled" >&2
fi

open "$install_path"

echo "installed: $install_path"
echo "config: $managed_config_path"
echo "codesign: $codesign_identity"

if [[ "$codesign_identity" == "-" ]]; then
  cat <<'EOF'
warning: using ad-hoc signing. macOS may treat each rebuild as a new app for
Accessibility permission. For stable permissions, install a local code-signing
identity and set AUN_CODESIGN_IDENTITY.
EOF
fi
