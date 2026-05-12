# Gemma 4 E4B Model Profile

Aun's default MVP inference profile targets Gemma 4 E4B instruction-tuned GGUF through llama.cpp.

## Default File Layout

```text
models/
  gemma-4-E4B-it-Q4_K_M.gguf
  gemma-4-E4B-it.prompt-cache
```

The model file is intentionally not committed to this repository.

When using the Nix development shell, `LLAMA_CLI` defaults to the `llama-cli` provided by nixpkgs. Override `AUN_MODEL_PATH` if the GGUF lives outside this repository.

## llama.cpp Defaults

```sh
llama-cli \
  -m models/gemma-4-E4B-it-Q4_K_M.gguf \
  --chat-template gemma \
  --ctx-size 8192 \
  --n-predict 64 \
  --temp 0.200 \
  -ngl 99 \
  --prompt-cache models/gemma-4-E4B-it.prompt-cache \
  --no-display-prompt
```

## Rationale

- E4B is small enough for local inline completion while being stronger than the smallest edge models.
- `Q4_K_M` keeps memory use appropriate for common Apple Silicon systems.
- `--chat-template gemma` is part of the default command because Gemma-family GGUFs need the matching chat template for stable output.
- `--prompt-cache` is enabled to support repeated inline completion prompts with low startup overhead.
