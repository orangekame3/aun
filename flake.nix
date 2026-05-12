{
  description = "Aun local AI inline completion assistant";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        commonPackages = with pkgs; [
          bash
          coreutils
          curl
          jq
          llama-cpp
          ripgrep
        ];

        aun-check = pkgs.writeShellApplication {
          name = "aun-check";
          runtimeInputs = commonPackages;
          text = ''
            set -euo pipefail
            exec scripts/check.sh "$@"
          '';
        };
      in
      {
        packages.default = aun-check;
        packages.aun-check = aun-check;

        apps.default = flake-utils.lib.mkApp {
          drv = aun-check;
        };

        devShells.default = pkgs.mkShell {
          packages = commonPackages ++ [ aun-check ];

          shellHook = ''
            export LLAMA_CLI="''${LLAMA_CLI:-${pkgs.llama-cpp}/bin/llama-completion}"
            export AUN_MODEL_PATH="''${AUN_MODEL_PATH:-models/gemma-4-E4B-it-Q4_K_M.gguf}"

            echo "Aun dev shell"
            echo "  scripts/download-model.sh"
            echo "  scripts/install-local-app.sh"
            echo "  aun-check"

            if ! { command -v swift >/dev/null 2>&1 && swift --version >/dev/null 2>&1; }; then
              echo "warning: Swift toolchain not found; install Xcode Command Line Tools" >&2
            fi
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
