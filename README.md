<p align="center">
  <img src="assets/brand/aun-logo.png" alt="Aun - Quietly completing your intent." width="560">
</p>

# Aun

Aun is a local AI inline completion assistant for macOS.

It watches the focused text field through macOS Accessibility APIs, shows a quiet ghost-text suggestion near the caret, and accepts it with `Tab`. Inference runs locally through `llama.cpp`.

## Status

Aun is early and experimental. The current build is intended for local testing on macOS, not production use.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools
- Nix, optional but recommended
- A local GGUF completion model

## Quick Start

Enter the development shell:

```sh
nix develop
```

Download the default Gemma GGUF:

```sh
make model
```

Install and launch the local app:

```sh
make install
```

Then allow Aun in `System Settings > Privacy & Security > Accessibility`.

Open TextEdit or another editable app, type a few characters, pause briefly, and press `Tab` to accept the suggestion.

## Keyboard

| Key | Action |
| --- | --- |
| `Tab` | Accept suggestion |
| `Esc` | Dismiss suggestion |
| `Option-Space` | Manually request suggestion |

## Development

Run checks:

```sh
make check
```

Build the app bundle:

```sh
make package
```

## Privacy

Aun is designed to run locally. The app does not send typed text to a network service. Model files are not committed to the repository.
