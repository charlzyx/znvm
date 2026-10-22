#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Testing znvm v2.4.0 ===${NC}"
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
if [[ "$VERSION_OUTPUT" == "v2.4.0" ]]; then
    echo -e "    ${GREEN}✓${NC} version command OK"
else
    echo -e "    ${RED}✗${NC} Expected v2.4.0, got $VERSION_OUTPUT"
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
# bash 3.2 exits on a failing command inside a function or $(...) even after
# set +e. Stay in the main script and capture through files.
trap 'echo "ERR status=$? line=${BASH_LINENO[0]} cmd=$BASH_COMMAND" >&2' ERR
echo "alias files before: alias=$(printf %q "$(cat "$ALIGN_ROOT/alias/default" 2>/dev/null || true)") legacy=$(printf %q "$(cat "$ALIGN_ROOT/default" 2>/dev/null || true)")" >&2
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" alias default 18 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
echo "alias status=$st stdout=$(printf %q "$(cat "$NVM_ALIGN_TMP/cmd.out" || true)") stderr=$(printf %q "$(cat "$NVM_ALIGN_TMP/cmd.err" || true)")" >&2
echo "alias files after: alias=$(printf %q "$(cat "$ALIGN_ROOT/alias/default" 2>/dev/null || true)") legacy=$(printf %q "$(cat "$ALIGN_ROOT/default" 2>/dev/null || true)")" >&2
if [[ "$st" -ne 0 ]]; then
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" default >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
echo "default status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
if [[ "$st" -ne 0 || "$out" != "18" ]]; then
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" version default >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
echo "version-default status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
if [[ "$st" -ne 0 || "$out" != "v18.0.0" ]]; then
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" which 20 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
echo "which-20 status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
if [[ "$st" -ne 0 || "$out" != "$ALIGN_ROOT/versions/node/v20.11.0/bin/node" ]]; then
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" which 18 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
echo "which-18 status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
if [[ "$st" -ne 0 || "$out" != "$ALIGN_ROOT/versions/v18.0.0/bin/node" ]]; then
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" current >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
echo "current status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
if [[ "$st" -ne 0 || "$out" != "none" ]]; then
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_ROOT/bin/nvm" version >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
echo "nvm-version status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
if [[ "$st" -ne 0 || "$out" != "none" ]]; then
    exit 1
fi
set +e
env -u NVM_DIR ZNVM_DIR="$ALIGN_ROOT" "$ALIGN_ROOT/bin/nvm" --version >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
echo "nvm-tool-version status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
if [[ "$st" -ne 0 || "$out" != "v2.4.0" ]]; then
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" version 99 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
echo "version-missing status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
if [[ "$st" -ne 3 || "$out" != "N/A" ]]; then
    exit 1
fi
# findUp prints the real path. macOS /var is a symlink to /private/var.
set +e
( cd "$ALIGN_ROOT/proj/sub" && env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" use ) >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 ]] || ! printf '%s\n' "$out" "$err" | grep -q "v20.11.0" || ! printf '%s\n' "$out" "$err" | grep -q "proj/.nvmrc"; then
    echo "FAIL use-nvmrc status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
( cd "$ALIGN_ROOT/nodever" && env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" use ) >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 ]] || ! printf '%s\n' "$out" "$err" | grep -q "nodever/.node-version" || ! printf '%s\n' "$out" "$err" | grep -q "v18.0.0"; then
    echo "FAIL use-node-version status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
( cd "$ALIGN_ROOT/save" && env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" use 20 --save >/dev/null )
test "$(cat "$ALIGN_ROOT/save/.nvmrc")" = "v20.11.0"
PATH="$ALIGN_ROOT/versions/v18.0.0/bin:/usr/bin:/bin" env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" "$ALIGN_BIN" reinstall-packages 20 >/dev/null
grep -q "install -g cowsay" "$ALIGN_ROOT/npm-log"
# NVM_DIR may be a symlink while PATH holds the real directory (macOS /var -> /private/var).
SYMLINK_TARGET="$NVM_ALIGN_TMP/symlink-target"
mkdir -p "$SYMLINK_TARGET/versions/v18.0.0/bin"
cp "$ALIGN_ROOT/versions/v18.0.0/bin/node" "$SYMLINK_TARGET/versions/v18.0.0/bin/node"
ln -s "$SYMLINK_TARGET" "$NVM_ALIGN_TMP/symlink-root"
set +e
env -u ZNVM_DIR NVM_DIR="$NVM_ALIGN_TMP/symlink-root" HOME="$NVM_ALIGN_TMP/home" PATH="$SYMLINK_TARGET/versions/v18.0.0/bin:/usr/bin:/bin" "$ALIGN_BIN" current >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || "$out" != "v18.0.0" ]]; then
    echo "FAIL symlink-current status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" install --copy-packages-from=9.9.9 20 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -eq 0 ]] || ! printf '%s\n' "$out" "$err" | grep -q "installed version of node"; then
    echo "FAIL copy-packages status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
( cd "$ALIGN_ROOT/proj" && env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" run --version ) >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 ]] || ! printf '%s\n' "$out" "$err" | grep -q "v20 --version"; then
    echo "FAIL run status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" exec 18 "$ALIGN_ROOT/versions/v18.0.0/bin/node" hi >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 ]] || ! printf '%s\n' "$out" "$err" | grep -q "v18 hi"; then
    echo "FAIL exec status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
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
    ver=$(nvm --version || true)
    if [ "$ver" != "v2.4.0" ]; then echo "shell nvm --version produced: $ver" >&2; exit 1; fi
' _ "$ALIGN_ROOT" "$ALIGN_BIN"
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" uninstall 18 >/dev/null
test ! -d "$ALIGN_ROOT/versions/v18.0.0"
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" install --offline 22.14.0 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -eq 0 ]] || ! printf '%s\n' "$out" "$err" | grep -q "cached tarball"; then
    echo "FAIL offline status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
trap - ERR
echo -e "    ${GREEN}✓${NC} nvm-compatible commands OK"

echo "  Testing install-as-nvm.sh..."
INSTALL_HOME="$NVM_ALIGN_TMP/home"
mkdir -p "$INSTALL_HOME/.nvm/versions/node/v1.2.3" "$INSTALL_HOME/.nvm"
touch "$INSTALL_HOME/.bashrc"
echo keep > "$INSTALL_HOME/.nvm/versions/node/v1.2.3/marker"
echo "echo original-nvm" > "$INSTALL_HOME/.nvm/nvm.sh"
echo "original completion" > "$INSTALL_HOME/.nvm/bash_completion"
INSTALL_OUT=$(env -i \
    HOME="$INSTALL_HOME" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ALIGN_BIN" \
    bash ./install-as-nvm.sh 2>&1)
printf '%s\n' "$INSTALL_OUT" | grep -q 'nvm is ready.'
printf '%s\n' "$INSTALL_OUT" | grep -q 'nvm install 22'
printf '%s\n' "$INSTALL_OUT" | grep -q 'nvm use 22'
printf '%s\n' "$INSTALL_OUT" | grep -q 'nvm ls'
printf '%s\n' "$INSTALL_OUT" | grep -q "export NVM_DIR=\"$INSTALL_HOME/.nvm\""
if printf '%s\n' "$INSTALL_OUT" | grep -q 'znvm\|completion'; then
    echo "install-as-nvm output mentioned znvm or completion" >&2
    printf '%s\n' "$INSTALL_OUT" >&2
    exit 1
fi
test -x "$INSTALL_HOME/.nvm/nvm"
test ! -e "$INSTALL_HOME/.znvm/bin/znvm"
grep -q "nvm: shell setup" "$INSTALL_HOME/.nvm/nvm.sh"
if grep -q 'znvm\|completion' "$INSTALL_HOME/.nvm/nvm.sh" "$INSTALL_HOME/.bashrc"; then
    echo "generated nvm files mentioned znvm or completion" >&2
    exit 1
fi
grep -q "echo original-nvm" "$INSTALL_HOME/.nvm/nvm.sh.bak"
test "$(cat "$INSTALL_HOME/.nvm/bash_completion")" = "original completion"
test ! -e "$INSTALL_HOME/.nvm/bash_completion.bak"
test ! -e "$INSTALL_HOME/.nvm/bash_completion.pre-znvm"
test "$(cat "$INSTALL_HOME/.nvm/versions/node/v1.2.3/marker")" = "keep"
test "$(grep -c 'NVM_DIR/nvm.sh' "$INSTALL_HOME/.bashrc")" -eq 1
env -i \
    HOME="$INSTALL_HOME" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ALIGN_BIN" \
    bash ./install-as-nvm.sh >/dev/null
test "$(grep -c 'NVM_DIR/nvm.sh' "$INSTALL_HOME/.bashrc")" -eq 1
grep -q "echo original-nvm" "$INSTALL_HOME/.nvm/nvm.sh.bak"
bash -c '
    set -e
    export HOME="$1"
    export PATH="$1/.nvm:/usr/bin:/bin"
    # shellcheck disable=SC1091
    . "$1/.nvm/nvm.sh"
    ver=$(nvm --version || true)
    if [ "$ver" != "v2.4.0" ]; then echo "nvm --version produced: $ver" >&2; exit 1; fi
    ver=$(nvm version || true)
    if [ "$ver" != "none" ]; then echo "nvm version produced: $ver" >&2; exit 1; fi
    ver=$(nvm current || true)
    if [ "$ver" != "none" ]; then echo "nvm current produced: $ver" >&2; exit 1; fi
    if type znvm >/dev/null 2>&1; then echo "znvm leaked into the shell" >&2; exit 1; fi
' _ "$INSTALL_HOME"
echo -e "    ${GREEN}✓${NC} install-as-nvm.sh OK"

echo "  Testing interactive guide..."
GUIDE_BIN="$ZNVM_BIN"
set +e
env -u NVM_DIR -u ZNVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" </dev/null >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
GUIDE_STATUS=$?
set -e
GUIDE_OUT=$(cat "$NVM_ALIGN_TMP/cmd.out" "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$GUIDE_STATUS" -ne 1 ]] || ! printf '%s\n' "$GUIDE_OUT" | grep -q "interactive guide needs a terminal"; then
    echo "FAIL bare-guide status=$GUIDE_STATUS out=$(printf %q "$GUIDE_OUT")" >&2
    exit 1
fi
set +e
env -u NVM_DIR -u ZNVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" guide </dev/null >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
GUIDE_STATUS=$?
set -e
GUIDE_OUT=$(cat "$NVM_ALIGN_TMP/cmd.out" "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$GUIDE_STATUS" -ne 1 ]] || ! printf '%s\n' "$GUIDE_OUT" | grep -q "interactive guide needs a terminal"; then
    echo "FAIL guide status=$GUIDE_STATUS out=$(printf %q "$GUIDE_OUT")" >&2
    exit 1
fi
set +e
env -u NVM_DIR -u ZNVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" interactive </dev/null >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
GUIDE_STATUS=$?
set -e
GUIDE_OUT=$(cat "$NVM_ALIGN_TMP/cmd.out" "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$GUIDE_STATUS" -ne 1 ]] || ! printf '%s\n' "$GUIDE_OUT" | grep -q "interactive guide needs a terminal"; then
    echo "FAIL interactive status=$GUIDE_STATUS out=$(printf %q "$GUIDE_OUT")" >&2
    exit 1
fi
HELP_OUT=$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" "$GUIDE_BIN" help)
printf '%s\n' "$HELP_OUT" | grep -q "interactive guide"
if printf '%s\n' "$HELP_OUT" | grep -q 'completion'; then
    echo "help mentioned completion" >&2
    exit 1
fi
ENV_GUIDE=$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" "$GUIDE_BIN" env)
printf '%s\n' "$ENV_GUIDE" | grep -q '__nvm_guide'
printf '%s\n' "$ENV_GUIDE" | grep -q 'guide|interactive'
python3 - "$GUIDE_BIN" "$EMPTY_ROOT" <<'PY'
import os, pty, select, subprocess, sys, time
bin_path, root = sys.argv[1], sys.argv[2]

def run_pty(args, env, sends, needles, timeout=5, stdout_pipe=False):
    master, slave = pty.openpty()
    stdout = subprocess.PIPE if stdout_pipe else slave
    proc = subprocess.Popen(args, stdin=slave, stdout=stdout, stderr=slave, env=env, close_fds=True)
    os.close(slave)
    data = b""
    pos = 0
    pending = list(sends)
    waiting = list(needles)
    end = time.time() + timeout
    while time.time() < end:
        r, _, _ = select.select([master], [], [], 0.2)
        if master in r:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            data += chunk
        while waiting:
            encoded = waiting[0].encode()
            found = data.find(encoded, pos)
            if found < 0:
                break
            pos = found + len(encoded)
            waiting.pop(0)
            if pending:
                os.write(master, pending.pop(0).encode())
        if proc.poll() is not None and not waiting:
            break
    else:
        proc.kill()
        text = data.decode("utf-8", "replace")
        raise SystemExit(f"timeout args={args[1:]} waiting={waiting!r}\n{text}")
    captured = b""
    if stdout_pipe:
        captured = proc.stdout.read()
    proc.wait(timeout=2)
    os.close(master)
    text = data.decode("utf-8", "replace")
    if waiting:
        raise SystemExit(f"missing {waiting!r} status={proc.returncode}\n{text}")
    return proc.returncode, text, captured.decode("utf-8", "replace")

base = os.environ.copy()
base.update({
    "LC_ALL": "C",
    "LANG": "C",
    "HOME": root + "/home",
    "PATH": "/usr/bin:/bin",
})
base.pop("NVM_DIR", None)
base.pop("ZNVM_DIR", None)
code, text, _ = run_pty(
    [bin_path],
    base,
    ["4\n", "1\n", "\n", "0\n"],
    ["Install Node", "Installed", "Press Enter to continue", "(interactive guide)"],
)
if code != 0:
    raise SystemExit(f"english menu exit {code}\n{text}")
if "No versions installed" not in text:
    raise SystemExit(f"ls did not run\n{text}")
zh = dict(base)
zh["LC_ALL"] = "zh_CN.UTF-8"
zh["LANG"] = "zh_CN.UTF-8"
code, text, _ = run_pty([bin_path], zh, ["0\n"], ["安装 Node"])
if code != 0:
    raise SystemExit(f"chinese menu exit {code}\n{text}")

nvm_dir = root + "/guide-node"
os.makedirs(nvm_dir + "/versions/node/v20.11.0/bin")
node = nvm_dir + "/versions/node/v20.11.0/bin/node"
with open(node, "w") as fh:
    fh.write("#!/bin/sh\nprintf 'v20 %s\\n' \"$*\"\n")
os.chmod(node, 0o755)
use_env = dict(base)
use_env["NVM_DIR"] = nvm_dir
code, text, _ = run_pty(
    [bin_path],
    use_env,
    ["2\n", "1\n", "1\n", "\n", "3\n", "1\n", "\n", "0\n"],
    [
        "Switch version (use)",
        "Choose an installed version",
        "v20.11.0",
        "Press Enter to continue",
        "Show current",
        "Active version",
        "Press Enter to continue",
        "(interactive guide)",
    ],
)
if code != 0:
    raise SystemExit(f"use menu exit {code}\n{text}")
if "export PATH=" not in text:
    raise SystemExit(f"use did not print shell exports\n{text}")
if text.rfind("v20.11.0") <= text.find("Using v20.11.0"):
    raise SystemExit(f"current did not run after use\n{text}")
code, screen, captured = run_pty(
    [bin_path, "--guide-step"],
    base,
    ["4\n", "1\n"],
    ["Install Node", "Installed", "No versions installed"],
    stdout_pipe=True,
)
if code != 0:
    raise SystemExit(f"step exit {code}\n{screen}\nSTDOUT:\n{captured}")
if "Install Node" in captured or "No versions installed" in captured:
    raise SystemExit(f"step stdout mixed with the menu\n{captured}")
code, text, _ = run_pty(
    [bin_path],
    base,
    ["9\n", "1\n", "\n", "0\n"],
    ["Registries (scopes)", "View the current map", "No registry map", "Press Enter to continue", "(interactive guide)"],
)
if code != 0:
    raise SystemExit(f"registry menu exit {code}\n{text}")
print("pty guide ok")
PY
echo -e "    ${GREEN}✓${NC} interactive guide OK"

echo "  Testing registry scopes..."
REG_HOME="$EMPTY_ROOT/registry-home"
REG_NVM="$EMPTY_ROOT/registry-nvm"
mkdir -p "$REG_HOME" "$REG_NVM"
printf '%s\n' 'fund=false' 'registry=https://keep.example' '//registry.npmjs.org/:_authToken=secret' > "$REG_HOME/.npmrc"
printf '%s\n' 'save-prefix "~"' > "$REG_HOME/.yarnrc"
reg() {
    env -u XDG_CONFIG_HOME HOME="$REG_HOME" NVM_DIR="$REG_NVM" "$ZNVM_BIN" registry "$@"
}
reg add @company https://npm.company.example
grep -q 'fund=false' "$REG_HOME/.npmrc"
grep -q 'registry=https://keep.example' "$REG_HOME/.npmrc"
grep -q '_authToken=secret' "$REG_HOME/.npmrc"
grep -q '@company:registry=https://npm.company.example' "$REG_HOME/.npmrc"
grep -q '@company:registry=https://npm.company.example' "$REG_HOME/.config/pnpm/rc"
grep -q 'save-prefix "~"' "$REG_HOME/.yarnrc"
grep -q '"@company:registry" "https://npm.company.example"' "$REG_HOME/.yarnrc"
grep -q 'company:' "$REG_HOME/.yarnrc.yml"
grep -q 'company = "https://npm.company.example"' "$REG_HOME/.bunfig.toml"
reg china
grep -q 'registry=https://registry.npmmirror.com' "$REG_HOME/.npmrc"
grep -q '@company:registry=https://npm.company.example' "$REG_HOME/.npmrc"
grep -q 'registry=https://registry.npmmirror.com' "$REG_HOME/.config/pnpm/rc"
grep -q 'registry "https://registry.npmmirror.com"' "$REG_HOME/.yarnrc"
grep -q 'npmRegistryServer: "https://registry.npmmirror.com"' "$REG_HOME/.yarnrc.yml"
grep -q 'registry = "https://registry.npmmirror.com"' "$REG_HOME/.bunfig.toml"
if grep -q 'keep.example' "$REG_HOME/.npmrc"; then
    echo "china left the previous default registry in place" >&2
    exit 1
fi
reg add @acme https://npm.acme.example
reg add @company https://npm.company.example/v2
test "$(grep -c '@company:registry=' "$REG_HOME/.npmrc")" -eq 1
grep -q '@company:registry=https://npm.company.example/v2' "$REG_HOME/.npmrc"
grep -q '@acme:registry=https://npm.acme.example' "$REG_HOME/.npmrc"
reg official
grep -q 'registry=https://registry.npmjs.org' "$REG_HOME/.npmrc"
grep -q '@acme:registry=https://npm.acme.example' "$REG_HOME/.npmrc"
grep -q 'registry=https://registry.npmjs.org' "$REG_HOME/.config/pnpm/rc"
reg remove @acme
if grep -q '@acme:registry' "$REG_HOME/.npmrc" "$REG_HOME/.config/pnpm/rc" "$REG_HOME/.yarnrc"; then
    echo "removed scope still present" >&2
    exit 1
fi
grep -q '@company:registry=https://npm.company.example/v2' "$REG_HOME/.npmrc"
set +e
reg add company https://npm.company.example >/tmp/znvm-registry-bad.txt 2>&1
REG_BAD=$?
set -e
test "$REG_BAD" -ne 0
grep -q 'Scope must look like @company' /tmp/znvm-registry-bad.txt
echo -e "    ${GREEN}✓${NC} registry scopes OK"

echo ""
echo -e "${GREEN}=== All tests passed! ===${NC}"

