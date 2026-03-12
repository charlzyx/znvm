#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Testing znvm v2.0.0-rc.1 ===${NC}"
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
if [[ "$VERSION_OUTPUT" == "v2.0.0-rc.1" ]]; then
    echo -e "    ${GREEN}✓${NC} version command OK"
else
    echo -e "    ${RED}✗${NC} Expected v2.0.0-rc.1, got $VERSION_OUTPUT"
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

