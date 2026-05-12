SHELL := /usr/bin/env bash

.PHONY: check build package install model clean

check:
	scripts/check.sh

build:
	swift build --package-path app

package:
	scripts/package-macos-app.sh

install:
	scripts/install-local-app.sh

model:
	scripts/download-model.sh

clean:
	rm -rf app/.build dist/Aun.app
