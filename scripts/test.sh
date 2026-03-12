#!/bin/bash

set -e

ZNVM_BIN="./zig-out/bin/znvm"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Create mock index.json
cat <<EOF > index.json
[
  {"version": "v20.11.0", "date": "2024-01-09", "files": ["osx-arm64-tar", "osx-x64-tar", "linux-x64"], "lts": "Iron", "security": false},
  {"version": "v20.10.0", "date": "2023-12-13", "files": ["osx-arm64-tar", "osx-x64-tar", "linux-x64"], "lts": "Iron", "security": false},
  {"version": "v18.19.0", "date": "2023-11-29", "files": ["osx-arm64-tar", "osx-x64-tar", "linux-x64"], "lts": "Hydrogen", "security": false},
  {"version": "v18.18.2", "date": "2023-10-13", "files": ["osx-arm64-tar", "osx-x64-tar", "linux-x64"], "lts": "Hydrogen", "security": false},
  {"version": "v16.20.2", "date": "2023-08-08", "files": ["osx-arm64-tar", "osx-x64-tar", "linux-x64"], "lts": false, "security": false}
]
EOF

echo "=== Testing resolve ==="

echo "Testing resolve 18..."
OUTPUT_18=$(cat index.json | "$ZNVM_BIN" resolve 18)
echo "Output: $OUTPUT_18"
if [[ "$OUTPUT_18" != "v18.19.0"* ]]; then
  echo -e "${RED}Expected v18.19.0*, got $OUTPUT_18${NC}"
  exit 1
fi

echo "Testing resolve 20..."
OUTPUT_20=$(cat index.json | "$ZNVM_BIN" resolve 20)
echo "Output: $OUTPUT_20"
if [[ "$OUTPUT_20" != "v20.11.0"* ]]; then
  echo -e "${RED}Expected v20.11.0*, got $OUTPUT_20${NC}"
  exit 1
fi

echo "Testing resolve latest..."
OUTPUT_LATEST=$(cat index.json | "$ZNVM_BIN" resolve latest)
echo "Output: $OUTPUT_LATEST"
if [[ "$OUTPUT_LATEST" != "v20.11.0"* ]]; then
  echo -e "${RED}Expected v20.11.0*, got $OUTPUT_LATEST${NC}"
  exit 1
fi

echo "Testing resolve lts..."
OUTPUT_LTS=$(cat index.json | "$ZNVM_BIN" resolve lts)
echo "Output: $OUTPUT_LTS"
if [[ "$OUTPUT_LTS" != "v20.11.0"* ]]; then
  echo -e "${RED}Expected v20.11.0* (latest LTS), got $OUTPUT_LTS${NC}"
  exit 1
fi

echo "=== Testing semver compare ==="

echo "Testing semver compare 18.19.0 20.11.0..."
CMP=$("$ZNVM_BIN" semver compare 18.19.0 20.11.0)
echo "Output: $CMP"
if [[ "$CMP" != "-1" ]]; then
  echo -e "${RED}Expected -1 (18.19.0 < 20.11.0), got $CMP${NC}"
  exit 1
fi

echo "Testing semver compare 20.11.0 18.19.0..."
CMP=$("$ZNVM_BIN" semver compare 20.11.0 18.19.0)
echo "Output: $CMP"
if [[ "$CMP" != "1" ]]; then
  echo -e "${RED}Expected 1 (20.11.0 > 18.19.0), got $CMP${NC}"
  exit 1
fi

echo "Testing semver compare 18.19.0 18.19.0..."
CMP=$("$ZNVM_BIN" semver compare 18.19.0 18.19.0)
echo "Output: $CMP"
if [[ "$CMP" != "0" ]]; then
  echo -e "${RED}Expected 0 (equal), got $CMP${NC}"
  exit 1
fi

echo "=== Testing semver match ==="

echo "Testing semver match 18..."
MATCH=$(echo -e "v18.19.0\nv18.18.2\nv20.11.0" | "$ZNVM_BIN" semver match 18)
echo "Output: $MATCH"
if [[ "$MATCH" != "v18.19.0" ]]; then
  echo -e "${RED}Expected v18.19.0, got $MATCH${NC}"
  exit 1
fi

echo "Testing semver match 20..."
MATCH=$(echo -e "v18.19.0\nv20.11.0\nv20.10.0" | "$ZNVM_BIN" semver match 20)
echo "Output: $MATCH"
if [[ "$MATCH" != "v20.11.0" ]]; then
  echo -e "${RED}Expected v20.11.0, got $MATCH${NC}"
  exit 1
fi

echo "Testing semver match latest..."
MATCH=$(echo -e "v16.20.2\nv18.19.0\nv20.11.0" | "$ZNVM_BIN" semver match latest)
echo "Output: $MATCH"
if [[ "$MATCH" != "v20.11.0" ]]; then
  echo -e "${RED}Expected v20.11.0, got $MATCH${NC}"
  exit 1
fi

# Cleanup
rm -f index.json

echo -e "${GREEN}=== All tests passed! ===${NC}"
