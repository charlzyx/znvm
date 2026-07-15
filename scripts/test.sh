#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Testing znvm v2.2.2 ===${NC}"
echo ""

# Run unit tests
echo -e "${YELLOW}Running unit tests...${NC}"
if zig build test; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
else
    echo -e "${RED}✗ Unit tests failed${NC}"
    exit 1
fi

echo ""

# Build the project
echo -e "${YELLOW}Building znvm binary...${NC}"
if zig build; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""

# Run integration tests
echo -e "${YELLOW}Running integration tests...${NC}"

ZNVM_BIN="./zig-out/bin/znvm"

# Test version command
echo "  Testing version command..."
VERSION_OUTPUT=$("$ZNVM_BIN" version)
if [[ "$VERSION_OUTPUT" == "v2.2.2" ]]; then
    echo -e "    ${GREEN}✓${NC} version command OK"
else
    echo -e "    ${RED}✗${NC} Expected v2.2.2, got $VERSION_OUTPUT"
    exit 1
fi

# Test env command
echo "  Testing env command..."
ENV_OUTPUT=$("$ZNVM_BIN" env)
if [[ -n "$ENV_OUTPUT" ]]; then
    echo -e "    ${GREEN}✓${NC} env command OK"
else
    echo -e "    ${RED}✗${NC} env command returned empty output"
    exit 1
fi

# Test shell quoting, shared prefix, PATH idempotence, and large output
echo "  Testing shell environment behavior..."
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
SPECIAL_ROOT="$TEST_ROOT/znvm space ';touch injected"
SPECIAL_ENV=$(ZNVM_DIR="$SPECIAL_ROOT" PATH="/usr/bin:/bin" "$ZNVM_BIN" env)
ZNVM_DIR="$SPECIAL_ROOT" bash -c '
    eval "$1"
    first_path=$PATH
    eval "$1"
    test "$PATH" = "$first_path"
    test "$NPM_CONFIG_PREFIX" = "$ZNVM_DIR/npm"
    case "$PATH" in
        "$NPM_CONFIG_PREFIX/bin:"*) ;;
        *) exit 1 ;;
    esac
' _ "$SPECIAL_ENV"
if [[ -e "$TEST_ROOT/injected" ]]; then
    echo -e "    ${RED}✗${NC} shell environment executed injected content"
    exit 1
fi

LONG_PATH="/usr/bin:/bin"
for i in $(seq 1 1000); do
    LONG_PATH="$LONG_PATH:/tmp/znvm-path-$i"
done
LONG_ENV=$(ZNVM_DIR="$TEST_ROOT/long" PATH="$LONG_PATH" "$ZNVM_BIN" env)
EXPECTED_PATH="$TEST_ROOT/long/npm/bin:$LONG_PATH"
bash -c 'eval "$1"; test "$PATH" = "$2"' _ "$LONG_ENV" "$EXPECTED_PATH"
echo -e "    ${GREEN}✓${NC} shell environment behavior OK"

# Test ls command (should show no versions installed)
echo "  Testing ls command..."
LS_OUTPUT=$("$ZNVM_BIN" ls 2>&1 || true)
if [[ "$LS_OUTPUT" == *"No versions installed"* ]]; then
    echo -e "    ${GREEN}✓${NC} ls command OK"
else
    echo -e "    ${RED}✗${NC} Expected 'No versions installed', got: $LS_OUTPUT"
    exit 1
fi

# Test default command (should show no default set)
echo "  Testing default command..."
DEFAULT_OUTPUT=$("$ZNVM_BIN" default 2>&1 || true)
if [[ "$DEFAULT_OUTPUT" == *"No default version set"* ]]; then
    echo -e "    ${GREEN}✓${NC} default command OK"
else
    echo -e "    ${RED}✗${NC} Expected 'No default version set', got: $DEFAULT_OUTPUT"
    exit 1
fi

echo ""
echo -e "${GREEN}=== All tests passed! ===${NC}"

