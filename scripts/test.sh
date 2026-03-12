#!/bin/bash

set -e

ZNVM_BIN="./zig-out/bin/znvm"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "=== Testing znvm v2.0.0-rc.1 ==="

# Test version command
echo "Testing version command..."
VERSION_OUTPUT=$("$ZNVM_BIN" version)
echo "Output: $VERSION_OUTPUT"
if [[ "$VERSION_OUTPUT" != "v2.0.0-rc.1" ]]; then
  echo -e "${RED}Expected v2.0.0-rc.1, got $VERSION_OUTPUT${NC}"
  exit 1
fi

# Test env command
echo "Testing env command..."
ENV_OUTPUT=$("$ZNVM_BIN" env)
if [[ -z "$ENV_OUTPUT" ]]; then
  echo -e "${RED}env command returned empty output${NC}"
  exit 1
fi
echo "env command OK"

# Test ls command (should show no versions installed)
echo "Testing ls command..."
LS_OUTPUT=$("$ZNVM_BIN" ls 2>&1 || true)
echo "Output: $LS_OUTPUT"
if [[ "$LS_OUTPUT" != *"No versions installed"* ]]; then
  echo -e "${RED}Expected 'No versions installed', got $LS_OUTPUT${NC}"
  exit 1
fi

# Test default command (should show no default set)
echo "Testing default command (no default set)..."
DEFAULT_OUTPUT=$("$ZNVM_BIN" default 2>&1 || true)
echo "Output: $DEFAULT_OUTPUT"
if [[ "$DEFAULT_OUTPUT" != *"No default version set"* ]]; then
  echo -e "${RED}Expected 'No default version set', got $DEFAULT_OUTPUT${NC}"
  exit 1
fi

echo -e "${GREEN}=== All tests passed! ===${NC}"
