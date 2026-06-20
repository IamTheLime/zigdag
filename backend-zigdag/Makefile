.PHONY: run build test check clean watch install help \
        python-package python-package-all \
        python-package-linux-x64 python-package-linux-arm64 \
        python-package-macos-x64 python-package-macos-arm64

# Default target
.DEFAULT_GOAL := help

## Run the CLI application
run:
	zig build run

## Build the project (library + executable)
build:
	zig build

## Run tests
test:
	zig build test

## Check if project compiles (used by ZLS for real-time diagnostics)
check:
	zig build check

## Generate Python package for the current platform
python-package:
	zig build python-package

## Generate Python package for Linux x86_64
python-package-linux-x64:
	zig build python-package-linux-x64

## Generate Python package for Linux arm64
python-package-linux-arm64:
	zig build python-package-linux-arm64

## Generate Python package for macOS x86_64
python-package-macos-x64:
	zig build python-package-macos-x64

## Generate Python package for macOS arm64
python-package-macos-arm64:
	zig build python-package-macos-arm64

## Generate Python packages for all supported platforms
python-package-all: python-package-linux-x64 python-package-linux-arm64 python-package-macos-x64 python-package-macos-arm64

## Clean build artifacts
clean:
	rm -rf zig-out .zig-cache zig-cache

## Watch for changes and run continuously (requires entr)
watch:
	@command -v entr >/dev/null 2>&1 || { echo "entr not found. Install with: apt install entr (Ubuntu) or brew install entr (macOS)"; exit 1; }
	@echo "Watching for changes... (Press Ctrl+C to stop)"
	@find src -name "*.zig" | entr -c zig build run

## Watch and run tests continuously (requires entr)
watch-test:
	@command -v entr >/dev/null 2>&1 || { echo "entr not found. Install with: apt install entr (Ubuntu) or brew install entr (macOS)"; exit 1; }
	@echo "Watching for changes and running tests... (Press Ctrl+C to stop)"
	@find src -name "*.zig" | entr -c zig build test

## Install the library and CLI
install:
	zig build install

## Development mode - build in debug with verbose output
dev:
	zig build -Doptimize=Debug run

## Release build
release:
	zig build -Doptimize=ReleaseFast

## Show this help message
help:
	@echo "OpenDAG Makefile Commands:"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /'
	@echo ""
	@echo "Quick start:"
	@echo "  make run        - Run the application"
	@echo "  make watch      - Auto-run on file changes"
	@echo "  make test       - Run tests"
