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

# Test shell quoting, PATH idempotence, and opt-in shared prefix
echo "  Testing shell environment behavior..."
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
SPECIAL_ROOT="$TEST_ROOT/znvm space ';touch injected"
SPECIAL_ENV=$(env -u NVM_DIR ZNVM_DIR="$SPECIAL_ROOT" PATH="/usr/bin:/bin" "$ZNVM_BIN" env)
env -u NVM_DIR ZNVM_DIR="$SPECIAL_ROOT" bash -c '
    eval "$1"
    first_path=$PATH
    eval "$1"
    test "$PATH" = "$first_path"
    test "$NVM_DIR" = "$ZNVM_DIR"
    test -z "${NPM_CONFIG_PREFIX-}"
' _ "$SPECIAL_ENV"
SHARED_ENV=$(env -u NVM_DIR ZNVM_DIR="$SPECIAL_ROOT" ZNVM_NPM_PREFIX="$SPECIAL_ROOT/npm" PATH="/usr/bin:/bin" "$ZNVM_BIN" env)
env -u NVM_DIR ZNVM_DIR="$SPECIAL_ROOT" ZNVM_NPM_PREFIX="$SPECIAL_ROOT/npm" bash -c '
    eval "$1"
    test "$NPM_CONFIG_PREFIX" = "$ZNVM_NPM_PREFIX"
    case "$PATH" in
        "$NPM_CONFIG_PREFIX/bin:"*) ;;
        *) exit 1 ;;
    esac
' _ "$SHARED_ENV"
if [[ -e "$TEST_ROOT/injected" ]]; then
    echo -e "    ${RED}✗${NC} shell environment executed injected content"
    exit 1
fi

LONG_PATH="/usr/bin:/bin"
for i in $(seq 1 1000); do
    LONG_PATH="$LONG_PATH:/tmp/znvm-path-$i"
done
LONG_ENV=$(env -u NVM_DIR ZNVM_DIR="$TEST_ROOT/long" ZNVM_NPM_PREFIX="$TEST_ROOT/long/npm" PATH="$LONG_PATH" "$ZNVM_BIN" env)
EXPECTED_PATH="$TEST_ROOT/long/npm/bin:$LONG_PATH"
bash -c 'eval "$1"; test "$PATH" = "$2"' _ "$LONG_ENV" "$EXPECTED_PATH"
echo -e "    ${GREEN}✓${NC} shell environment behavior OK"

# Test ls command (should show no versions installed)
echo "  Testing ls command..."
EMPTY_ROOT=$(mktemp -d)
LS_OUTPUT=$(env -u ZNVM_DIR NVM_DIR="$EMPTY_ROOT" HOME="$EMPTY_ROOT/home" "$ZNVM_BIN" ls 2>&1 || true)
if [[ "$LS_OUTPUT" == *"No versions installed"* ]]; then
    echo -e "    ${GREEN}✓${NC} ls command OK"
else
    echo -e "    ${RED}✗${NC} Expected 'No versions installed', got: $LS_OUTPUT"
    exit 1
fi

# Test default command (should show no default set)
echo "  Testing default command..."
DEFAULT_OUTPUT=$(env -u ZNVM_DIR NVM_DIR="$EMPTY_ROOT" HOME="$EMPTY_ROOT/home" "$ZNVM_BIN" default 2>&1 || true)
if [[ "$DEFAULT_OUTPUT" == *"No default version set"* ]]; then
    echo -e "    ${GREEN}✓${NC} default command OK"
else
    echo -e "    ${RED}✗${NC} Expected 'No default version set', got: $DEFAULT_OUTPUT"
    exit 1
fi

echo "  Testing nvm-compatible commands..."
NVM_ALIGN_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT" "$EMPTY_ROOT" "$NVM_ALIGN_TMP"' EXIT
ALIGN_ROOT="$NVM_ALIGN_TMP/root"
mkdir -p "$ALIGN_ROOT/versions/node/v20.11.0/bin" "$ALIGN_ROOT/versions/v18.0.0/bin" \
    "$ALIGN_ROOT/versions/node/v20.11.0/lib/node_modules/cowsay" \
    "$ALIGN_ROOT/proj/sub" "$ALIGN_ROOT/nodever" "$ALIGN_ROOT/bin" "$ALIGN_ROOT/save"
printf '#!/bin/sh\nprintf "v18 %%s\\n" "$*"\n' > "$ALIGN_ROOT/versions/v18.0.0/bin/node"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/npm-log"\n' "$ALIGN_ROOT" > "$ALIGN_ROOT/versions/v18.0.0/bin/npm"
printf '#!/bin/sh\nprintf "v20 %%s\\n" "$*"\n' > "$ALIGN_ROOT/versions/node/v20.11.0/bin/node"
printf '%s\n' '{"name":"cowsay","version":"1.5.0"}' > "$ALIGN_ROOT/versions/node/v20.11.0/lib/node_modules/cowsay/package.json"
chmod +x "$ALIGN_ROOT/versions/v18.0.0/bin/node" "$ALIGN_ROOT/versions/v18.0.0/bin/npm" \
    "$ALIGN_ROOT/versions/node/v20.11.0/bin/node"
printf '20 # pin\n' > "$ALIGN_ROOT/proj/.nvmrc"
printf '18\n' > "$ALIGN_ROOT/nodever/.node-version"
cp "$ZNVM_BIN" "$ALIGN_ROOT/bin/znvm"
ln -s znvm "$ALIGN_ROOT/bin/nvm"
ALIGN_BIN="$ALIGN_ROOT/bin/znvm"

ALIGN_LS=$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" ls)
printf '%s\n' "$ALIGN_LS" | grep -q "v18.0.0"
printf '%s\n' "$ALIGN_LS" | grep -q "v20.11.0"
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" alias default 18 >/dev/null
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" default)" = "18"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" version default)" = "v18.0.0"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" which 20)" = "$ALIGN_ROOT/versions/node/v20.11.0/bin/node"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" which 18)" = "$ALIGN_ROOT/versions/v18.0.0/bin/node"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" current)" = "none"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_ROOT/bin/nvm" version)" = "none"
test "$(env -u NVM_DIR ZNVM_DIR="$ALIGN_ROOT" "$ALIGN_ROOT/bin/nvm" --version)" = "v2.2.2"
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" version 99 >/dev/null
ALIGN_STATUS=$?
set -e
test "$ALIGN_STATUS" -eq 3
USE_OUT=$(cd "$ALIGN_ROOT/proj/sub" && env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" use 2>&1)
printf '%s\n' "$USE_OUT" | grep -q "v20.11.0"
printf '%s\n' "$USE_OUT" | grep -q "Found '$ALIGN_ROOT/proj/.nvmrc'"
NODEVER_OUT=$(cd "$ALIGN_ROOT/nodever" && env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" use 2>&1)
printf '%s\n' "$NODEVER_OUT" | grep -q "Found '$ALIGN_ROOT/nodever/.node-version'"
printf '%s\n' "$NODEVER_OUT" | grep -q "v18.0.0"
( cd "$ALIGN_ROOT/save" && env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" use 20 --save >/dev/null )
test "$(cat "$ALIGN_ROOT/save/.nvmrc")" = "v20.11.0"
PATH="$ALIGN_ROOT/versions/v18.0.0/bin:/usr/bin:/bin" env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" "$ALIGN_BIN" reinstall-packages 20 >/dev/null
grep -q "install -g cowsay" "$ALIGN_ROOT/npm-log"
set +e
COPY_FROM_OUT=$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" install --copy-packages-from=9.9.9 20 2>&1)
COPY_FROM_STATUS=$?
set -e
test "$COPY_FROM_STATUS" -ne 0
printf '%s\n' "$COPY_FROM_OUT" | grep -q "installed version of node"
RUN_OUT=$(cd "$ALIGN_ROOT/proj" && env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" run --version)
printf '%s\n' "$RUN_OUT" | grep -q "v20 --version"
EXEC_OUT=$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" exec 18 "$ALIGN_ROOT/versions/v18.0.0/bin/node" hi)
printf '%s\n' "$EXEC_OUT" | grep -q "v18 hi"
bash -c '
    set -e
    unset NVM_DIR
    eval "$(ZNVM_DIR="$1" "$2" env)"
    cd "$1/proj/sub"
    nvm use >/dev/null
    out=$(node)
    case "$out" in
        "v20 "*) ;;
        *) echo "shell use produced: $out" >&2; exit 1 ;;
    esac
    test "$(nvm --version)" = "v2.2.2"
' _ "$ALIGN_ROOT" "$ALIGN_BIN"
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" uninstall 18 >/dev/null
test ! -d "$ALIGN_ROOT/versions/v18.0.0"
set +e
OFFLINE_OUT=$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" install --offline 22.14.0 2>&1)
ALIGN_STATUS=$?
set -e
test "$ALIGN_STATUS" -ne 0
printf '%s\n' "$OFFLINE_OUT" | grep -q "cached tarball"
echo -e "    ${GREEN}✓${NC} nvm-compatible commands OK"

echo "  Testing install-as-nvm.sh..."
INSTALL_HOME="$NVM_ALIGN_TMP/home"
mkdir -p "$INSTALL_HOME/.nvm/versions/node/v1.2.3" "$INSTALL_HOME/.nvm"
touch "$INSTALL_HOME/.bashrc"
echo keep > "$INSTALL_HOME/.nvm/versions/node/v1.2.3/marker"
echo "echo original-nvm" > "$INSTALL_HOME/.nvm/nvm.sh"
echo "original completion" > "$INSTALL_HOME/.nvm/bash_completion"
env -i \
    HOME="$INSTALL_HOME" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ALIGN_BIN" \
    ZNVM_INSTALL_BIN_DIR="$INSTALL_HOME/.znvm/bin" \
    bash ./install-as-nvm.sh >/dev/null
test -x "$INSTALL_HOME/.znvm/bin/znvm"
test -L "$INSTALL_HOME/.znvm/bin/nvm"
test "$(readlink "$INSTALL_HOME/.znvm/bin/nvm")" = "znvm"
grep -q "znvm-nvm-shim" "$INSTALL_HOME/.nvm/nvm.sh"
grep -q "echo original-nvm" "$INSTALL_HOME/.nvm/nvm.sh.pre-znvm"
grep -q "original completion" "$INSTALL_HOME/.nvm/bash_completion.pre-znvm"
test "$(cat "$INSTALL_HOME/.nvm/versions/node/v1.2.3/marker")" = "keep"
grep -q 'znvm-nvm-shim' "$INSTALL_HOME/.bashrc"
test "$(grep -c 'znvm-nvm-shim' "$INSTALL_HOME/.bashrc")" -eq 1
env -i \
    HOME="$INSTALL_HOME" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ALIGN_BIN" \
    ZNVM_INSTALL_BIN_DIR="$INSTALL_HOME/.znvm/bin" \
    bash ./install-as-nvm.sh >/dev/null
test "$(grep -c 'znvm-nvm-shim' "$INSTALL_HOME/.bashrc")" -eq 1
grep -q "echo original-nvm" "$INSTALL_HOME/.nvm/nvm.sh.pre-znvm"
bash -c '
    set -e
    export HOME="$1"
    export PATH="$1/.znvm/bin:/usr/bin:/bin"
    # shellcheck disable=SC1091
    . "$1/.nvm/nvm.sh"
    test "$(nvm --version)" = "v2.2.2"
    test "$(command -v nvm >/dev/null; nvm current)" = "none"
' _ "$INSTALL_HOME"
echo -e "    ${GREEN}✓${NC} install-as-nvm.sh OK"

echo ""
echo -e "${GREEN}=== All tests passed! ===${NC}"

