#!/bin/bash

# OpenPricing Playground Test Script
# Tests pricing models from the playground/ directory

set -e

PLAYGROUND_DIR="playground"
PRICING_MODEL="${PLAYGROUND_DIR}/pricing_model.json"
BACKEND_DIR="backend-openpricing"
OUTPUT_DIR="${PLAYGROUND_DIR}/output"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create output directory
mkdir -p "${OUTPUT_DIR}"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

test_pricing_model() {
    print_header "Testing Playground Pricing Model"
    
    # Check if pricing model exists
    if [ ! -f "${PRICING_MODEL}" ]; then
        print_error "No pricing model found at ${PRICING_MODEL}"
        print_info "Create one using the frontend or copy an example"
        exit 1
    fi
    
    print_success "Found pricing model: ${PRICING_MODEL}"
    
    # Validate JSON
    print_info "Validating JSON..."
    if ! jq empty "${PRICING_MODEL}" 2>/dev/null; then
        print_error "Invalid JSON in pricing model"
        exit 1
    fi
    print_success "JSON is valid"
    
    # Show node count
    NODE_COUNT=$(jq '.nodes | length' "${PRICING_MODEL}")
    print_info "Model has ${NODE_COUNT} nodes"
    
    # Show node types
    print_info "Node types:"
    jq -r '.nodes[] | "  - \(.id): \(.operation)"' "${PRICING_MODEL}"
    
    # Copy to backend models directory
    print_info "Copying to backend..."
    cp "${PRICING_MODEL}" "${BACKEND_DIR}/models/pricing_model.json"
    print_success "Copied to backend/models/"
    
    # Build the backend
    print_header "Building Backend (Compile-Time Optimization)"
    cd "${BACKEND_DIR}"
    
    if make build 2>&1 | tee "../${OUTPUT_DIR}/build.log"; then
        print_success "Build successful!"
    else
        print_error "Build failed! Check ${OUTPUT_DIR}/build.log for details"
        cd ..
        exit 1
    fi
    cd ..
    
    # Run the compiled binary
    print_header "Executing Pricing Model"
    if "${BACKEND_DIR}/zig-out/bin/openpricing-cli" 2>&1 | tee "${OUTPUT_DIR}/execution.log"; then
        print_success "Execution successful!"
    else
        print_error "Execution failed! Check ${OUTPUT_DIR}/execution.log"
        exit 1
    fi
    
    print_header "Test Complete"
    print_success "All tests passed!"
    print_info "Logs saved to ${OUTPUT_DIR}/"
}

watch_mode() {
    print_header "Watch Mode - Monitoring for Changes"
    print_info "Watching ${PRICING_MODEL}"
    print_info "Press Ctrl+C to stop"
    echo ""
    
    # Initial test
    test_pricing_model
    echo ""
    
    # Watch for changes (requires inotify-tools on Linux, fswatch on macOS)
    if command -v inotifywait &> /dev/null; then
        # Linux
        while inotifywait -e modify,create "${PRICING_MODEL}" 2>/dev/null; do
            echo ""
            print_info "Change detected! Re-testing..."
            echo ""
            test_pricing_model
            echo ""
            print_info "Waiting for changes..."
        done
    elif command -v fswatch &> /dev/null; then
        # macOS
        fswatch -o "${PRICING_MODEL}" | while read -r; do
            echo ""
            print_info "Change detected! Re-testing..."
            echo ""
            test_pricing_model
            echo ""
            print_info "Waiting for changes..."
        done
    else
        print_error "Watch mode requires inotifywait (Linux) or fswatch (macOS)"
        print_info "Install with: sudo apt install inotify-tools (Linux) or brew install fswatch (macOS)"
        print_info "Running single test instead..."
        exit 1
    fi
}

# Main script
case "${1:-}" in
    --watch|-w)
        watch_mode
        ;;
    --help|-h)
        echo "OpenPricing Playground Test Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  (no args)     Run a single test"
        echo "  -w, --watch   Watch for changes and auto-test"
        echo "  -h, --help    Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0              # Run once"
        echo "  $0 --watch      # Watch for changes"
        ;;
    *)
        test_pricing_model
        ;;
esac
