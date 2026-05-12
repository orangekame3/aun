#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

model_url="${AUN_MODEL_URL:-https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q4_K_M.gguf}"
model_path="${AUN_MODEL_PATH:-models/gemma-4-E4B-it-Q4_K_M.gguf}"

mkdir -p "$(dirname "$model_path")"
curl -L "$model_url" -o "$model_path"

if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$model_path" >"$model_path.sha256"
fi

echo "downloaded: $model_path"
