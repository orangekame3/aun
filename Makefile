SHELL := /usr/bin/env bash
export AUN_BUNDLE_NAME
export AUN_CODESIGN_IDENTITY
export AUN_INSTALL_DIR
export AUN_MODEL_PATH
export AUN_PROMPT_CACHE
export LLAMA_CLI

.PHONY: check build package install reinstall clean-install model clean reset-accessibility

check:
	scripts/check.sh

build:
	swift build --package-path app

package:
	scripts/package-macos-app.sh

install:
	scripts/install-local-app.sh

reinstall: clean-install

clean-install: clean
	$(MAKE) install

model:
	scripts/download-model.sh

clean:
	rm -rf app/.build dist/Aun.app "$${AUN_INSTALL_DIR:-$$HOME/Applications}/$${AUN_BUNDLE_NAME:-Aun}.app"

reset-accessibility:
	scripts/reset-accessibility.sh
