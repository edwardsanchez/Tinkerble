.DEFAULT_GOAL := help

SHELL := /bin/bash

XCODE_BETA_DEVELOPER_DIR := /Applications/Xcode-beta.app/Contents/Developer
ifneq ($(wildcard $(XCODE_BETA_DEVELOPER_DIR)),)
export DEVELOPER_DIR ?= $(XCODE_BETA_DEVELOPER_DIR)
endif

PROJECT := Tinkerble Demo/Tinkerble Demo.xcodeproj
DEMO_SCHEME := Tinkerble Demo
DEMO_PACKAGE_CACHE := .build-demo-validation
SIMULATOR_DESTINATION := generic/platform=iOS Simulator
DEVICE_DESTINATION := generic/platform=iOS
REMOTE ?= origin
VERSION ?=

.PHONY: help
help: ## Show available commands.
	@awk 'BEGIN {FS = ":.*##"; printf "Tinkerble commands:\n"} /^[a-zA-Z0-9][a-zA-Z0-9_-]*:.*##/ {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: test
test: ## Run the Swift package test suite.
	swift test

.PHONY: test-installer
test-installer: ## Run installer-focused tests.
	swift test --filter TinkerbleInstallerCoreTests

.PHONY: test-preview-fixtures
test-preview-fixtures: ## Run companion preview fixture tests.
	swift test --filter TinkerbleComponentPreviewFixtureTests

.PHONY: test-inspector
test-inspector: ## Run companion inspector content tests.
	swift test --filter TweakInspectorContentTests

.PHONY: companion
companion: ## Package the macOS companion app.
	./Scripts/package-macos-companion.sh

.PHONY: companion-run
companion-run: ## Package, restart, and verify the macOS companion is listening.
	./Scripts/launch-macos-companion.sh

.PHONY: companion-verify
companion-verify: ## Package and verify the macOS companion bundle.
	./Scripts/verify-macos-companion-package.sh

.PHONY: demo-build
demo-build: ## Build the iOS demo for Simulator.
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(DEMO_SCHEME)" \
	  -destination "$(SIMULATOR_DESTINATION)" \
	  -clonedSourcePackagesDirPath "$(DEMO_PACKAGE_CACHE)" \
	  -skipMacroValidation \
	  build

.PHONY: demo-simulator
demo-simulator: ## Build, install, and launch the demo on a Simulator. Set TINKERBLE_SIMULATOR_UDID to avoid interactive choice.
	./Scripts/run-tinkerble-demo.sh

.PHONY: demo-simulator-ci
demo-simulator-ci: ## Build, install, and launch the demo on the first available iPhone Simulator.
	TINKERBLE_INTERACTIVE=0 ./Scripts/run-tinkerble-demo.sh

.PHONY: demo-device-build
demo-device-build: ## Build the demo for a generic physical iOS device.
	xcodebuild \
	  -project "$(PROJECT)" \
	  -scheme "$(DEMO_SCHEME)" \
	  -destination "$(DEVICE_DESTINATION)" \
	  -clonedSourcePackagesDirPath "$(DEMO_PACKAGE_CACHE)" \
	  -skipMacroValidation \
	  build

.PHONY: verify
verify: test companion-verify demo-build ## Run package tests, companion verification, and demo Simulator build.

.PHONY: release-check
release-check: verify ## Run local checks expected before tagging a release.
	git diff --check
	git status --short

.PHONY: release-tag
release-tag: release-check ## Create a local annotated release tag. Usage: make release-tag VERSION=v1.2.3
	@test -n "$(VERSION)" || { echo "VERSION is required, e.g. make release-tag VERSION=v1.2.3"; exit 2; }
	git tag -a "$(VERSION)" -m "$(VERSION)"

.PHONY: release-push-tag
release-push-tag: ## Push an existing release tag. Usage: make release-push-tag VERSION=v1.2.3
	@test -n "$(VERSION)" || { echo "VERSION is required, e.g. make release-push-tag VERSION=v1.2.3"; exit 2; }
	git push "$(REMOTE)" "$(VERSION)"

.PHONY: release-github
release-github: ## Create the GitHub release for an existing tag. Usage: make release-github VERSION=v1.2.3
	@test -n "$(VERSION)" || { echo "VERSION is required, e.g. make release-github VERSION=v1.2.3"; exit 2; }
	gh release create "$(VERSION)" --latest --title "$(VERSION)" --notes ""

.PHONY: release-verify
release-verify: ## Verify a published GitHub release. Usage: make release-verify VERSION=v1.2.3
	@test -n "$(VERSION)" || { echo "VERSION is required, e.g. make release-verify VERSION=v1.2.3"; exit 2; }
	git ls-remote --tags "$(REMOTE)" "$(VERSION)"
	gh release view "$(VERSION)" --json tagName,targetCommitish,url
