#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Testing znvm v2.9.2 ===${NC}"
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
if [[ "$VERSION_OUTPUT" == "v2.9.2" ]]; then
    echo -e "    ${GREEN}✓${NC} version command OK"
else
    echo -e "    ${RED}✗${NC} Expected v2.9.2, got $VERSION_OUTPUT"
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
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" alias default 18 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || -n "$out" ]]; then
    echo "FAIL alias status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" default >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || "$out" != "18" ]]; then
    echo "FAIL status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" version default >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || "$out" != "v18.0.0" ]]; then
    echo "FAIL status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" which 20 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || "$out" != "$ALIGN_ROOT/versions/node/v20.11.0/bin/node" ]]; then
    echo "FAIL status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" which 18 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || "$out" != "$ALIGN_ROOT/versions/v18.0.0/bin/node" ]]; then
    echo "FAIL status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" current >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || "$out" != "none" ]]; then
    echo "FAIL status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_ROOT/bin/nvm" version >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || "$out" != "none" ]]; then
    echo "FAIL status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u NVM_DIR ZNVM_DIR="$ALIGN_ROOT" "$ALIGN_ROOT/bin/nvm" --version >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 0 || "$out" != "v2.9.2" ]]; then
    echo "FAIL status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
    exit 1
fi
set +e
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" version 99 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
st=$?
set -e
out=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
err=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$st" -ne 3 || "$out" != "N/A" ]]; then
    echo "FAIL status=$st stdout=$(printf %q "$out") stderr=$(printf %q "$err")" >&2
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
    if [ "$ver" != "v2.9.2" ]; then echo "shell nvm --version produced: $ver" >&2; exit 1; fi
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
printf '%s\n' "$INSTALL_OUT" | grep -q '^Done\.$'
printf '%s\n' "$INSTALL_OUT" | grep -q 'source ~/.bashrc'
printf '%s\n' "$INSTALL_OUT" | grep -q '^mirror: official$'
if printf '%s\n' "$INSTALL_OUT" | grep -q 'nvm is ready\|nvm install 22\|Node versions are stored'; then
    echo "install-as-nvm footer was not shortened" >&2
    printf '%s\n' "$INSTALL_OUT" >&2
    exit 1
fi
if printf '%s\n' "$INSTALL_OUT" | grep -q 'znvm\|completion'; then
    echo "install-as-nvm output mentioned znvm or completion" >&2
    printf '%s\n' "$INSTALL_OUT" >&2
    exit 1
fi
test -x "$INSTALL_HOME/.nvm/nvm"
test -L "$INSTALL_HOME/.nvm/nrm"
test "$(readlink "$INSTALL_HOME/.nvm/nrm")" = "nvm"
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
grep -q "export NODEJS_ORG_MIRROR='https://nodejs.org/dist'" "$INSTALL_HOME/.nvm/binaries.env"
grep -q "export NVM_NODEJS_ORG_MIRROR='https://nodejs.org/dist'" "$INSTALL_HOME/.nvm/binaries.env"
if grep -q ELECTRON_MIRROR "$INSTALL_HOME/.nvm/binaries.env"; then
    echo "official install set a binary mirror" >&2
    exit 1
fi
grep -q 'registry=https://registry.npmjs.org' "$INSTALL_HOME/.npmrc"
echo '# keep-me' >> "$INSTALL_HOME/.nvm/binaries.env"
test "$(cat "$INSTALL_HOME/.nvm/versions/node/v1.2.3/marker")" = "keep"
test "$(grep -c 'NVM_DIR/nvm.sh' "$INSTALL_HOME/.bashrc")" -eq 1
env -i \
    HOME="$INSTALL_HOME" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ALIGN_BIN" \
    bash ./install-as-nvm.sh >/dev/null
test "$(grep -c 'NVM_DIR/nvm.sh' "$INSTALL_HOME/.bashrc")" -eq 1
grep -q '# keep-me' "$INSTALL_HOME/.nvm/binaries.env"
grep -q "echo original-nvm" "$INSTALL_HOME/.nvm/nvm.sh.bak"
bash -c '
    set -e
    export HOME="$1"
    export PATH="$1/.nvm:/usr/bin:/bin"
    # shellcheck disable=SC1091
    . "$1/.nvm/nvm.sh"
    ver=$(nvm --version || true)
    if [ "$ver" != "v2.9.2" ]; then echo "nvm --version produced: $ver" >&2; exit 1; fi
    ver=$(nvm version || true)
    if [ "$ver" != "none" ]; then echo "nvm version produced: $ver" >&2; exit 1; fi
    ver=$(nvm current || true)
    if [ "$ver" != "none" ]; then echo "nvm current produced: $ver" >&2; exit 1; fi
    if type znvm >/dev/null 2>&1; then echo "znvm leaked into the shell" >&2; exit 1; fi
' _ "$INSTALL_HOME"
echo -e "    ${GREEN}✓${NC} install-as-nvm.sh OK"

echo "  Testing install mirror preset..."
preset_install() {
    env -i \
        HOME="$1" \
        PATH="/usr/bin:/bin" \
        SHELL="/bin/bash" \
        ZNVM_BIN_SRC="$ALIGN_BIN" \
        ${2:+LC_ALL="$2"} \
        ${3:+NVM_MIRROR="$3"} \
        ${4:+NVM_LANG="$4"} \
        bash ./install-as-nvm.sh
}
ZH_HOME="$NVM_ALIGN_TMP/zh-home"
mkdir -p "$ZH_HOME"
touch "$ZH_HOME/.bashrc"
ZH_PRESET_OUT=$(preset_install "$ZH_HOME" zh_CN.UTF-8 "" "")
printf '%s\n' "$ZH_PRESET_OUT" | grep -q '^镜像: china$'
if printf '%s\n' "$ZH_PRESET_OUT" | grep -qE '已写入 ~/.|Wrote .*/(\.npmrc|\.yarnrc|binaries\.env)'; then
    echo "zh preset should not list per-file mirror writes" >&2
    printf '%s\n' "$ZH_PRESET_OUT" >&2
    exit 1
fi
grep -q "export ELECTRON_MIRROR='https://cdn.npmmirror.com/binaries/electron/'" "$ZH_HOME/.nvm/binaries.env"
grep -q "export NVM_NODEJS_ORG_MIRROR='https://cdn.npmmirror.com/binaries/node'" "$ZH_HOME/.nvm/binaries.env"
grep -q 'registry=https://registry.npmmirror.com' "$ZH_HOME/.npmrc"
OFF_HOME="$NVM_ALIGN_TMP/off-home"
mkdir -p "$OFF_HOME"
touch "$OFF_HOME/.bashrc"
preset_install "$OFF_HOME" zh_CN.UTF-8 official "" >/dev/null
grep -q "export NVM_NODEJS_ORG_MIRROR='https://nodejs.org/dist'" "$OFF_HOME/.nvm/binaries.env"
if grep -q ELECTRON_MIRROR "$OFF_HOME/.nvm/binaries.env"; then
    echo "NVM_MIRROR=official set a binary mirror" >&2
    exit 1
fi
grep -q 'registry=https://registry.npmjs.org' "$OFF_HOME/.npmrc"
KEEP_HOME="$NVM_ALIGN_TMP/keep-home"
mkdir -p "$KEEP_HOME/.nvm"
echo 'export KEEP_MIRROR=1' > "$KEEP_HOME/.nvm/binaries.env"
touch "$KEEP_HOME/.bashrc"
preset_install "$KEEP_HOME" zh_CN.UTF-8 china "" >/dev/null
grep -q 'export KEEP_MIRROR=1' "$KEEP_HOME/.nvm/binaries.env"
if grep -q ELECTRON_MIRROR "$KEEP_HOME/.nvm/binaries.env"; then
    echo "existing mirror config was replaced" >&2
    exit 1
fi
test ! -e "$KEEP_HOME/.nvm/registries.json"
BAD_HOME="$NVM_ALIGN_TMP/bad-home"
mkdir -p "$BAD_HOME"
touch "$BAD_HOME/.bashrc"
set +e
BAD_OUT=$(preset_install "$BAD_HOME" C auto "" 2>&1)
BAD_ST=$?
set -e
if [ "$BAD_ST" -eq 0 ] || ! printf '%s\n' "$BAD_OUT" | grep -q "NVM_MIRROR must be china or official"; then
    echo "bad NVM_MIRROR status=$BAD_ST out=$(printf %q "$BAD_OUT")" >&2
    exit 1
fi
LANG_HOME="$NVM_ALIGN_TMP/lang-home"
mkdir -p "$LANG_HOME"
touch "$LANG_HOME/.bashrc"
preset_install "$LANG_HOME" C "" zh >/dev/null
grep -q "export ELECTRON_MIRROR=" "$LANG_HOME/.nvm/binaries.env"
echo -e "    ${GREEN}✓${NC} install mirror preset OK"

echo "  Testing install-as-nvm.sh upgrades an older binary..."
REAL_BIN="$(cd "$(dirname "$ZNVM_BIN")" && pwd)/$(basename "$ZNVM_BIN")"
write_old_binary() {
    cat > "$1" <<'EOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
    echo v2.3.0
    exit 0
fi
if [ "$1" = "ls" ]; then
    echo v20.11.0
    exit 0
fi
echo old
exit 0
EOF
    chmod +x "$1"
}
write_fake_curl() {
    mkdir -p "$1"
    if [ "$3" = "fail" ]; then
        cat > "$1/curl" <<EOF
#!/bin/sh
echo fail >> "$2"
exit 1
EOF
    else
        cat > "$1/curl" <<EOF
#!/bin/sh
echo called >> "$2"
out=""
while [ \$# -gt 0 ]; do
    case "\$1" in
        -o)
            out="\$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done
if [ -z "\$out" ]; then
    echo "fake curl missing -o" >&2
    exit 1
fi
cp "$REAL_BIN" "\$out"
chmod +x "\$out"
EOF
    fi
    chmod +x "$1/curl"
}
UPGRADE_HOME="$NVM_ALIGN_TMP/upgrade-home"
mkdir -p "$UPGRADE_HOME/.nvm/versions/node/v1.2.3"
echo keep-upgrade > "$UPGRADE_HOME/.nvm/versions/node/v1.2.3/marker"
write_old_binary "$UPGRADE_HOME/.nvm/nvm"
touch "$UPGRADE_HOME/.bashrc"
CURL_DIR="$NVM_ALIGN_TMP/fake-curl"
CURL_MARK="$NVM_ALIGN_TMP/curl-calls"
: > "$CURL_MARK"
write_fake_curl "$CURL_DIR" "$CURL_MARK" copy
UPGRADE_OUT=$(env -i \
    HOME="$UPGRADE_HOME" \
    PATH="$CURL_DIR:/usr/bin:/bin" \
    SHELL="/bin/bash" \
    bash ./install-as-nvm.sh 2>&1)
printf '%s\n' "$UPGRADE_OUT" | grep -q "ok Upgraded nvm v2.3.0 -> v2.9.2"
printf '%s\n' "$UPGRADE_OUT" | grep -q "Saved the previous $UPGRADE_HOME/.nvm/nvm as $UPGRADE_HOME/.nvm/nvm.bak"
printf '%s\n' "$UPGRADE_OUT" | grep -q "ok Linked $UPGRADE_HOME/.nvm/nrm -> nvm"
if printf '%s\n' "$UPGRADE_OUT" | grep -q 'znvm\|completion'; then
    echo "upgrade output mentioned znvm or completion" >&2
    printf '%s\n' "$UPGRADE_OUT" >&2
    exit 1
fi
test "$(readlink "$UPGRADE_HOME/.nvm/nrm")" = "nvm"
ver=$("$UPGRADE_HOME/.nvm/nvm" --version)
if [ "$ver" != "v2.9.2" ]; then echo "upgraded nvm --version produced: $ver" >&2; exit 1; fi
ver=$("$UPGRADE_HOME/.nvm/nvm.bak" --version)
if [ "$ver" != "v2.3.0" ]; then echo "nvm.bak --version produced: $ver" >&2; exit 1; fi
test "$("$UPGRADE_HOME/.nvm/nvm.bak" ls)" = "v20.11.0"
NRM_LS=$(env -i HOME="$UPGRADE_HOME" PATH="/usr/bin:/bin" "$UPGRADE_HOME/.nvm/nrm" ls)
printf '%s\n' "$NRM_LS" | grep -q "taobao https://registry.npmmirror.com/"
if printf '%s\n' "$NRM_LS" | grep -q 'v20.11.0'; then
    echo "nrm ls still listed a Node version" >&2
    printf '%s\n' "$NRM_LS" >&2
    exit 1
fi
test "$(cat "$UPGRADE_HOME/.nvm/versions/node/v1.2.3/marker")" = "keep-upgrade"
test "$(grep -c '^called$' "$CURL_MARK")" -eq 1
SECOND_OUT=$(env -i \
    HOME="$UPGRADE_HOME" \
    PATH="$CURL_DIR:/usr/bin:/bin" \
    SHELL="/bin/bash" \
    bash ./install-as-nvm.sh 2>&1)
printf '%s\n' "$SECOND_OUT" | grep -q "ok nvm is already installed at $UPGRADE_HOME/.nvm/nvm"
if printf '%s\n' "$SECOND_OUT" | grep -q 'Upgraded'; then
    echo "matching version was upgraded again" >&2
    exit 1
fi
test "$(grep -c '^called$' "$CURL_MARK")" -eq 1
ver=$("$UPGRADE_HOME/.nvm/nvm.bak" --version)
if [ "$ver" != "v2.3.0" ]; then echo "second run replaced nvm.bak: $ver" >&2; exit 1; fi
if printf '%s\n' "$SECOND_OUT" | grep -q 'znvm\|completion'; then
    echo "second upgrade output mentioned znvm or completion" >&2
    exit 1
fi
FAIL_HOME="$NVM_ALIGN_TMP/upgrade-fail-home"
mkdir -p "$FAIL_HOME/.nvm"
write_old_binary "$FAIL_HOME/.nvm/nvm"
touch "$FAIL_HOME/.bashrc"
FAIL_CURL="$NVM_ALIGN_TMP/fake-curl-fail"
FAIL_MARK="$NVM_ALIGN_TMP/curl-fail-calls"
: > "$FAIL_MARK"
write_fake_curl "$FAIL_CURL" "$FAIL_MARK" fail
set +e
FAIL_OUT=$(env -i \
    HOME="$FAIL_HOME" \
    PATH="$FAIL_CURL:/usr/bin:/bin" \
    SHELL="/bin/bash" \
    bash ./install-as-nvm.sh 2>&1)
FAIL_ST=$?
set -e
if [ "$FAIL_ST" -eq 0 ]; then
    echo "failed download exited 0" >&2
    printf '%s\n' "$FAIL_OUT" >&2
    exit 1
fi
ver=$("$FAIL_HOME/.nvm/nvm" --version)
if [ "$ver" != "v2.3.0" ]; then echo "failed download replaced nvm: $ver" >&2; exit 1; fi
test ! -e "$FAIL_HOME/.nvm/nvm.bak"
test -z "$(find "$FAIL_HOME/.nvm" -name '.nvm-new.*' -print)"
SRC_HOME="$NVM_ALIGN_TMP/upgrade-src-home"
mkdir -p "$SRC_HOME/.nvm"
write_old_binary "$SRC_HOME/.nvm/nvm"
touch "$SRC_HOME/.bashrc"
SRC_OUT=$(env -i \
    HOME="$SRC_HOME" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$REAL_BIN" \
    bash ./install-as-nvm.sh 2>&1)
printf '%s\n' "$SRC_OUT" | grep -q "ok Upgraded nvm v2.3.0 -> v2.9.2"
ver=$("$SRC_HOME/.nvm/nvm" --version)
if [ "$ver" != "v2.9.2" ]; then echo "ZNVM_BIN_SRC upgrade produced: $ver" >&2; exit 1; fi
ver=$("$SRC_HOME/.nvm/nvm.bak" --version)
if [ "$ver" != "v2.3.0" ]; then echo "ZNVM_BIN_SRC bak produced: $ver" >&2; exit 1; fi
if printf '%s\n' "$SRC_OUT" | grep -q 'znvm\|completion'; then
    echo "ZNVM_BIN_SRC upgrade output mentioned znvm or completion" >&2
    printf '%s\n' "$SRC_OUT" >&2
    exit 1
fi
echo -e "    ${GREEN}✓${NC} install-as-nvm.sh upgrade OK"

echo "  Testing nrm link, foreign nrm, and uninstall..."
FOREIGN_HOME="$NVM_ALIGN_TMP/foreign-home"
mkdir -p "$FOREIGN_HOME/other" "$FOREIGN_HOME/.nvm/versions/node/v9.9.9" "$FOREIGN_HOME/.nvm"
echo keep-foreign > "$FOREIGN_HOME/.nvm/versions/node/v9.9.9/marker"
printf '#!/bin/sh\necho foreign-nrm\n' > "$FOREIGN_HOME/other/nrm"
chmod +x "$FOREIGN_HOME/other/nrm"
echo "echo original-nvm" > "$FOREIGN_HOME/.nvm/nvm.sh"
touch "$FOREIGN_HOME/.bashrc"
FOREIGN_OUT=$(env -i \
    HOME="$FOREIGN_HOME" \
    PATH="$FOREIGN_HOME/other:/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ALIGN_BIN" \
    bash ./install-as-nvm.sh 2>&1)
printf '%s\n' "$FOREIGN_OUT" | grep -q "note: another nrm is at $FOREIGN_HOME/other/nrm and was not removed."
printf '%s\n' "$FOREIGN_OUT" | grep -q "ok Linked $FOREIGN_HOME/.nvm/nrm -> nvm"
test "$(readlink "$FOREIGN_HOME/.nvm/nrm")" = "nvm"
test "$(bash "$FOREIGN_HOME/other/nrm")" = "foreign-nrm"
test "$(cat "$FOREIGN_HOME/.nvm/versions/node/v9.9.9/marker")" = "keep-foreign"
if printf '%s\n' "$FOREIGN_OUT" | grep -q 'znvm\|completion'; then
    echo "foreign install output mentioned znvm or completion" >&2
    printf '%s\n' "$FOREIGN_OUT" >&2
    exit 1
fi
OCCUPIED="$NVM_ALIGN_TMP/occupied-home"
mkdir -p "$OCCUPIED/.nvm"
printf '#!/bin/sh\necho occupied-nrm\n' > "$OCCUPIED/.nvm/nrm"
chmod +x "$OCCUPIED/.nvm/nrm"
touch "$OCCUPIED/.bashrc"
OCCUPIED_OUT=$(env -i \
    HOME="$OCCUPIED" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ALIGN_BIN" \
    bash ./install-as-nvm.sh 2>&1)
printf '%s\n' "$OCCUPIED_OUT" | grep -q "note: $OCCUPIED/.nvm/nrm already exists and was not changed."
test ! -L "$OCCUPIED/.nvm/nrm"
test "$(bash "$OCCUPIED/.nvm/nrm")" = "occupied-nrm"
UNINSTALL_OUT=$(env -i \
    HOME="$FOREIGN_HOME" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ALIGN_BIN" \
    bash ./install-as-nvm.sh --uninstall 2>&1)
printf '%s\n' "$UNINSTALL_OUT" | grep -q "ok Removed $FOREIGN_HOME/.nvm/nrm"
printf '%s\n' "$UNINSTALL_OUT" | grep -q "ok Removed $FOREIGN_HOME/.nvm/nvm"
printf '%s\n' "$UNINSTALL_OUT" | grep -q "ok Restored $FOREIGN_HOME/.nvm/nvm.sh"
printf '%s\n' "$UNINSTALL_OUT" | grep -q "Node versions in $FOREIGN_HOME/.nvm were kept."
test ! -e "$FOREIGN_HOME/.nvm/nvm"
test ! -e "$FOREIGN_HOME/.nvm/nrm"
test "$(cat "$FOREIGN_HOME/.nvm/nvm.sh")" = "echo original-nvm"
test "$(cat "$FOREIGN_HOME/.nvm/versions/node/v9.9.9/marker")" = "keep-foreign"
test "$(bash "$FOREIGN_HOME/other/nrm")" = "foreign-nrm"
if grep -q 'nvm: shell setup' "$FOREIGN_HOME/.bashrc"; then
    echo "uninstall left the nvm shell block in bashrc" >&2
    exit 1
fi
if printf '%s\n' "$UNINSTALL_OUT" | grep -q 'znvm\|completion'; then
    echo "uninstall output mentioned znvm or completion" >&2
    printf '%s\n' "$UNINSTALL_OUT" >&2
    exit 1
fi
echo -e "    ${GREEN}✓${NC} nrm install link OK"

echo "  Testing install.sh uninstall..."
PLAIN_HOME="$NVM_ALIGN_TMP/plain-home"
mkdir -p "$PLAIN_HOME/.local/bin" "$PLAIN_HOME/other" "$PLAIN_HOME/.znvm/versions"
echo keep-znvm > "$PLAIN_HOME/.znvm/versions/marker"
printf '#!/bin/sh\necho znvm-bin\n' > "$PLAIN_HOME/.local/bin/znvm"
chmod +x "$PLAIN_HOME/.local/bin/znvm"
ln -s znvm "$PLAIN_HOME/.local/bin/nrm"
printf '#!/bin/sh\necho foreign-nrm\n' > "$PLAIN_HOME/other/nrm"
chmod +x "$PLAIN_HOME/other/nrm"
cat > "$PLAIN_HOME/.bashrc" <<'EOF'
echo kept
# znvm
export PATH="$HOME/.znvm/bin:$PATH"
eval "$(znvm env)"
echo after
EOF
PLAIN_OUT=$(env -i \
    HOME="$PLAIN_HOME" \
    PATH="$PLAIN_HOME/other:$PLAIN_HOME/.local/bin:/usr/bin:/bin" \
    SHELL="/bin/bash" \
    bash ./install.sh --uninstall 2>&1)
printf '%s\n' "$PLAIN_OUT" | grep -q "ok Removed $PLAIN_HOME/.local/bin/nrm"
printf '%s\n' "$PLAIN_OUT" | grep -q "ok Removed $PLAIN_HOME/.local/bin/znvm"
printf '%s\n' "$PLAIN_OUT" | grep -q "ok Removed znvm startup from $PLAIN_HOME/.bashrc"
test ! -e "$PLAIN_HOME/.local/bin/znvm"
test ! -e "$PLAIN_HOME/.local/bin/nrm"
test "$(bash "$PLAIN_HOME/other/nrm")" = "foreign-nrm"
test "$(cat "$PLAIN_HOME/.znvm/versions/marker")" = "keep-znvm"
grep -q '^echo kept$' "$PLAIN_HOME/.bashrc"
grep -q '^echo after$' "$PLAIN_HOME/.bashrc"
if grep -q 'znvm env' "$PLAIN_HOME/.bashrc"; then
    echo "uninstall left the znvm env line" >&2
    exit 1
fi
echo -e "    ${GREEN}✓${NC} install.sh uninstall OK"

echo "  Testing install.sh upgrades an older binary..."
PLAIN_UP="$NVM_ALIGN_TMP/plain-upgrade-home"
mkdir -p "$PLAIN_UP/.local/bin" "$PLAIN_UP/.znvm/versions"
echo keep-plain > "$PLAIN_UP/.znvm/versions/marker"
write_old_binary "$PLAIN_UP/.local/bin/znvm"
touch "$PLAIN_UP/.bashrc"
PLAIN_CURL="$NVM_ALIGN_TMP/plain-fake-curl"
PLAIN_MARK="$NVM_ALIGN_TMP/plain-curl-calls"
: > "$PLAIN_MARK"
write_fake_curl "$PLAIN_CURL" "$PLAIN_MARK" copy
PLAIN_UP_OUT=$(env -i \
    HOME="$PLAIN_UP" \
    PATH="$PLAIN_CURL:$PLAIN_UP/.local/bin:/usr/bin:/bin" \
    SHELL="/bin/bash" \
    bash ./install.sh 2>&1)
printf '%s\n' "$PLAIN_UP_OUT" | grep -q "ok Upgraded znvm v2.3.0 -> v2.9.2"
printf '%s\n' "$PLAIN_UP_OUT" | grep -q "Saved the previous $PLAIN_UP/.local/bin/znvm as $PLAIN_UP/.local/bin/znvm.bak"
printf '%s\n' "$PLAIN_UP_OUT" | grep -q "ok Linked $PLAIN_UP/.local/bin/nrm -> znvm"
test "$(readlink "$PLAIN_UP/.local/bin/nrm")" = "znvm"
ver=$("$PLAIN_UP/.local/bin/znvm" --version)
if [ "$ver" != "v2.9.2" ]; then echo "upgraded znvm --version produced: $ver" >&2; exit 1; fi
ver=$("$PLAIN_UP/.local/bin/znvm.bak" --version)
if [ "$ver" != "v2.3.0" ]; then echo "znvm.bak --version produced: $ver" >&2; exit 1; fi
PLAIN_NRM_LS=$(env -i HOME="$PLAIN_UP" PATH="/usr/bin:/bin" "$PLAIN_UP/.local/bin/nrm" ls)
printf '%s\n' "$PLAIN_NRM_LS" | grep -q "taobao https://registry.npmmirror.com/"
if printf '%s\n' "$PLAIN_NRM_LS" | grep -q 'v20.11.0'; then
    echo "install.sh nrm ls still listed a Node version" >&2
    printf '%s\n' "$PLAIN_NRM_LS" >&2
    exit 1
fi
test "$(cat "$PLAIN_UP/.znvm/versions/marker")" = "keep-plain"
test "$(grep -c '^called$' "$PLAIN_MARK")" -eq 1
PLAIN_SECOND=$(env -i \
    HOME="$PLAIN_UP" \
    PATH="$PLAIN_CURL:$PLAIN_UP/.local/bin:/usr/bin:/bin" \
    SHELL="/bin/bash" \
    bash ./install.sh 2>&1)
printf '%s\n' "$PLAIN_SECOND" | grep -q "ok znvm is already installed at $PLAIN_UP/.local/bin/znvm"
if printf '%s\n' "$PLAIN_SECOND" | grep -q 'Upgraded'; then
    echo "install.sh upgraded a matching version" >&2
    exit 1
fi
test "$(grep -c '^called$' "$PLAIN_MARK")" -eq 1
PLAIN_FAIL="$NVM_ALIGN_TMP/plain-fail-home"
mkdir -p "$PLAIN_FAIL/.local/bin"
write_old_binary "$PLAIN_FAIL/.local/bin/znvm"
touch "$PLAIN_FAIL/.bashrc"
PLAIN_FAIL_CURL="$NVM_ALIGN_TMP/plain-fake-curl-fail"
PLAIN_FAIL_MARK="$NVM_ALIGN_TMP/plain-curl-fail"
: > "$PLAIN_FAIL_MARK"
write_fake_curl "$PLAIN_FAIL_CURL" "$PLAIN_FAIL_MARK" fail
set +e
PLAIN_FAIL_OUT=$(env -i \
    HOME="$PLAIN_FAIL" \
    PATH="$PLAIN_FAIL_CURL:$PLAIN_FAIL/.local/bin:/usr/bin:/bin" \
    SHELL="/bin/bash" \
    bash ./install.sh 2>&1)
PLAIN_FAIL_ST=$?
set -e
if [ "$PLAIN_FAIL_ST" -eq 0 ]; then
    echo "install.sh failed download exited 0" >&2
    printf '%s\n' "$PLAIN_FAIL_OUT" >&2
    exit 1
fi
ver=$("$PLAIN_FAIL/.local/bin/znvm" --version)
if [ "$ver" != "v2.3.0" ]; then echo "install.sh failed download replaced znvm: $ver" >&2; exit 1; fi
test ! -e "$PLAIN_FAIL/.local/bin/znvm.bak"
test -z "$(find "$PLAIN_FAIL/.local/bin" -name '.znvm-new.*' -print)"
echo -e "    ${GREEN}✓${NC} install.sh upgrade OK"

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
HELP_OUT=$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" help)
printf '%s\n' "$HELP_OUT" | grep -q "Usage: znvm <command>"
printf '%s\n' "$HELP_OUT" | grep -q "NVM_DIR"
printf '%s\n' "$HELP_OUT" | grep -q "NVM_NODEJS_ORG_MIRROR"
printf '%s\n' "$HELP_OUT" | grep -q "NVM_LANG"
printf '%s\n' "$HELP_OUT" | grep -q "NVM_MIRROR"
printf '%s\n' "$HELP_OUT" | grep -F -q 'mirror [ls|use|set|reset|test]'
if printf '%s\n' "$HELP_OUT" | grep -q 'Docker image'; then
    echo "help still has the long notes" >&2
    exit 1
fi
HELP_ONE=$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" help install)
printf '%s\n' "$HELP_ONE" | grep -F -q "Usage: znvm install [version]"
HELP_ZH=$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" NVM_LANG=zh LC_ALL=C "$GUIDE_BIN" help)
printf '%s\n' "$HELP_ZH" | grep -q "用法: znvm <命令>"
test "$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" lang)" = "en"
test "$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=en_US.UTF-8 "$GUIDE_BIN" lang)" = "en"
test "$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=fr_FR.UTF-8 "$GUIDE_BIN" lang)" = "en"
test "$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=zh_CN.UTF-8 "$GUIDE_BIN" lang)" = "zh"
test "$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" NVM_LANG=en LC_ALL=zh_CN.UTF-8 "$GUIDE_BIN" lang)" = "en"
test "$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" NVM_LANG=zh_CN LC_ALL=zh_CN.UTF-8 "$GUIDE_BIN" lang)" = "zh"
ZH_UNKNOWN=$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" NVM_LANG=zh LC_ALL=C "$GUIDE_BIN" nosuch 2>&1 || true)
printf '%s\n' "$ZH_UNKNOWN" | grep -q "未知命令: nosuch"
EN_LS_JSON=$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" ls --json)
ZH_LS_JSON=$(env -u NVM_DIR HOME="$EMPTY_ROOT/home" NVM_LANG=zh LC_ALL=C "$GUIDE_BIN" ls --json)
test "$EN_LS_JSON" = "$ZH_LS_JSON"
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
base.pop("CI", None)
base.pop("NVM_NONINTERACTIVE", None)
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
code, text, _ = run_pty(
    [bin_path],
    base,
    ["10\n", "0\n", "0\n"],
    ["Mirrors", "Use china", "(interactive guide)"],
)
if code != 0:
    raise SystemExit(f"mirror menu exit {code}\n{text}")
code, text, _ = run_pty(
    [bin_path],
    base,
    ["\x1b[B\x1b[B\r", "\x1b[D", "q"],
    ["Show current", "Active version", "(interactive guide)"],
)
if code != 0 or ">  3  Show current" not in text:
    raise SystemExit(f"arrow menu exit {code}\n{text}")
code, text, _ = run_pty(
    [bin_path],
    base,
    ["j\r", "k\r", "q"],
    ["Switch version (use)", "Choose an installed version", "(interactive guide)"],
)
if code != 0:
    raise SystemExit(f"vim keys exit {code}\n{text}")
code, text, _ = run_pty([bin_path], base, ["\x03"], ["(interactive guide)"])
if code != 130:
    raise SystemExit(f"ctrl-c exit {code}\n{text}")
plain = dict(base)
plain["NO_COLOR"] = "1"
code, text, _ = run_pty([bin_path], plain, ["0\n"], [">  1  Install Node"])
if code != 0 or "\x1b[1;7m" in text or "\x1b[7m" in text:
    raise SystemExit(f"NO_COLOR menu exit {code}\n{text}")
colored = dict(base)
colored.pop("NO_COLOR", None)
colored["TERM"] = "xterm-256color"
code, text, _ = run_pty([bin_path], colored, ["q"], ["\x1b[1;7m>  1  Install Node"])
if code != 0:
    raise SystemExit(f"color menu exit {code}\n{text}")

def expect_closed(args, env, label):
    code, text, _ = run_pty(args, env, [], ["interactive guide needs a terminal"], timeout=3)
    if code != 1 or "Install Node" in text:
        raise SystemExit(f"{label} exit {code}\n{text}")

ci = dict(base)
ci["CI"] = "1"
expect_closed([bin_path], ci, "CI")
nonint = dict(base)
nonint["NVM_NONINTERACTIVE"] = "Yes"
expect_closed([bin_path], nonint, "NVM_NONINTERACTIVE")
expect_closed([bin_path, "--yes"], base, "--yes")
code, screen, captured = run_pty(
    [bin_path],
    base,
    [],
    ["interactive guide needs a terminal"],
    stdout_pipe=True,
    timeout=3,
)
if code != 1 or "Install Node" in captured or "Install Node" in screen:
    raise SystemExit(f"stdout pipe exit {code}\n{screen}\nSTDOUT:\n{captured}")
off = dict(base)
off["NVM_NONINTERACTIVE"] = "0"
code, text, _ = run_pty([bin_path], off, ["0\n"], ["Install Node"])
if code != 0:
    raise SystemExit(f"NVM_NONINTERACTIVE=0 exit {code}\n{text}")
print("pty guide ok")
PY
echo -e "    ${GREEN}✓${NC} interactive guide OK"

echo "  Testing registry scopes..."
REG_HOME="$EMPTY_ROOT/registry-home"
REG_NVM="$EMPTY_ROOT/registry-nvm"
mkdir -p "$REG_HOME" "$REG_NVM"
# pnpm follows ~/Library/Preferences on macOS when XDG_CONFIG_HOME is unset.
if [[ "$(uname -s)" == "Darwin" ]]; then
    PNPM_RC="$REG_HOME/Library/Preferences/pnpm/rc"
else
    PNPM_RC="$REG_HOME/.config/pnpm/rc"
fi
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
grep -q '@company:registry=https://npm.company.example' "$PNPM_RC"
grep -q 'save-prefix "~"' "$REG_HOME/.yarnrc"
grep -q '"@company:registry" "https://npm.company.example"' "$REG_HOME/.yarnrc"
grep -q 'company:' "$REG_HOME/.yarnrc.yml"
grep -q 'company = "https://npm.company.example"' "$REG_HOME/.bunfig.toml"
reg china
grep -q 'registry=https://registry.npmmirror.com' "$REG_HOME/.npmrc"
grep -q '@company:registry=https://npm.company.example' "$REG_HOME/.npmrc"
grep -q 'registry=https://registry.npmmirror.com' "$PNPM_RC"
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
grep -q 'registry=https://registry.npmjs.org' "$PNPM_RC"
reg remove @acme
if grep -q '@acme:registry' "$REG_HOME/.npmrc" "$PNPM_RC" "$REG_HOME/.yarnrc"; then
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

echo "  Testing nrm command..."
NRM_HOME="$EMPTY_ROOT/nrm-home"
NRM_NVM="$EMPTY_ROOT/nrm-nvm"
mkdir -p "$NRM_HOME" "$NRM_NVM" "$EMPTY_ROOT/nrm-bin"
NRM_TARGET="$(cd "$(dirname "$ZNVM_BIN")" && pwd)/$(basename "$ZNVM_BIN")"
ln -sfn "$NRM_TARGET" "$EMPTY_ROOT/nrm-bin/nrm"
nrm_run() {
    env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" LC_ALL=C "$EMPTY_ROOT/nrm-bin/nrm" "$@"
}
set +e
nrm_run </dev/null >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
NRM_STATUS=$?
set -e
NRM_OUT=$(cat "$NVM_ALIGN_TMP/cmd.out" "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$NRM_STATUS" -ne 0 ]] || ! printf '%s\n' "$NRM_OUT" | grep -q "nrm - registry manager"; then
    echo "FAIL bare nrm status=$NRM_STATUS out=$(printf %q "$NRM_OUT")" >&2
    exit 1
fi
if printf '%s\n' "$NRM_OUT" | grep -q "needs a terminal"; then
    echo "bare nrm asked for a terminal" >&2
    exit 1
fi
nrm_run help | grep -q "scope add"
nrm_run ls >"$NVM_ALIGN_TMP/cmd.out"
grep -q "  npm https://registry.npmjs.org/" "$NVM_ALIGN_TMP/cmd.out"
grep -q "  taobao https://registry.npmmirror.com/" "$NVM_ALIGN_TMP/cmd.out"
if grep -q '^\* ' "$NVM_ALIGN_TMP/cmd.out"; then
    echo "nrm ls starred a registry before use" >&2
    exit 1
fi
nrm_run use taobao >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
grep -q "The registry has been changed to 'taobao'." "$NVM_ALIGN_TMP/cmd.out"
grep -q "Wrote $NRM_HOME/.npmrc" "$NVM_ALIGN_TMP/cmd.err"
grep -q 'registry=https://registry.npmmirror.com/' "$NRM_HOME/.npmrc"
test "$(nrm_run current)" = "taobao"
test "$(nrm_run current -u)" = "https://registry.npmmirror.com/"
env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" "$ZNVM_BIN" registry china >/dev/null
test "$(nrm_run current)" = "taobao"
grep -q 'registry=https://registry.npmmirror.com' "$NRM_HOME/.npmrc"
env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" "$ZNVM_BIN" registry official >/dev/null
test "$(nrm_run current)" = "npm"
nrm_run add local http://127.0.0.1:1 | grep -q "added local"
nrm_run ls | grep -q "  local http://127.0.0.1:1"
nrm_run test local >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
grep -q "^local error$" "$NVM_ALIGN_TMP/cmd.out"
set +e
nrm_run del npm >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
NRM_STATUS=$?
set -e
if [[ "$NRM_STATUS" -eq 0 ]] || ! grep -q "error: npm is a built-in registry." "$NVM_ALIGN_TMP/cmd.err"; then
    echo "FAIL del builtin status=$NRM_STATUS" >&2
    exit 1
fi
set +e
nrm_run add npm https://example.com >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
NRM_STATUS=$?
set -e
if [[ "$NRM_STATUS" -eq 0 ]] || ! grep -q "error: npm is a built-in registry." "$NVM_ALIGN_TMP/cmd.err"; then
    echo "FAIL add builtin status=$NRM_STATUS" >&2
    exit 1
fi
nrm_run del local | grep -q "deleted local"
if nrm_run ls | grep -q "local "; then
    echo "deleted registry still listed" >&2
    exit 1
fi
nrm_run scope add @company https://npm.company.example >/dev/null
nrm_run scope ls | grep -q "@company https://npm.company.example"
grep -q '@company:registry=https://npm.company.example' "$NRM_HOME/.npmrc"
nrm_run scope del @company >/dev/null
if grep -q '@company:registry=' "$NRM_HOME/.npmrc"; then
    echo "scope del left the scope in npmrc" >&2
    exit 1
fi
printf '%s\n' 'fund=false' '//registry.npmjs.org/:_authToken=secret' >> "$NRM_HOME/.npmrc"
if [[ "$(uname -s)" == "Darwin" ]]; then
    NRM_PNPM="$NRM_HOME/Library/Preferences/pnpm/rc"
else
    NRM_PNPM="$NRM_HOME/.config/pnpm/rc"
fi
mirror_run() {
    env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" LC_ALL=C "$ZNVM_BIN" mirror "$@"
}
if nrm_run help | grep -q 'binary '; then
    echo "nrm help listed binary mirrors" >&2
    exit 1
fi
nrm_run help | grep -q "nvm mirror"
env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" LC_ALL=C "$ZNVM_BIN" help | grep -F -q 'mirror [ls|use|set|reset|test]'
set +e
nrm_run binary ls >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
NRM_STATUS=$?
set -e
if [[ "$NRM_STATUS" -eq 0 ]] || ! grep -q "nrm - registry manager" "$NVM_ALIGN_TMP/cmd.out"; then
    echo "FAIL nrm binary status=$NRM_STATUS" >&2
    exit 1
fi
set +e
nrm_run mirror ls >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
NRM_STATUS=$?
set -e
if [[ "$NRM_STATUS" -eq 0 ]] || ! grep -q "nrm - registry manager" "$NVM_ALIGN_TMP/cmd.out"; then
    echo "FAIL nrm mirror status=$NRM_STATUS" >&2
    exit 1
fi
mirror_run ls >"$NVM_ALIGN_TMP/cmd.out"
grep -q '^profile official$' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  electron (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  sqlite3 (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  canvas (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  grpc (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  grpc-tools (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  nodejieba (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  xprofiler (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  gdal-async (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  ali-zeromq (unset)' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  ali-usb_ctl (unset)' "$NVM_ALIGN_TMP/cmd.out"
mirror_run ls --json >"$NVM_ALIGN_TMP/mirror.json"
grep -q '"name":"sqlite3"' "$NVM_ALIGN_TMP/mirror.json"
grep -q '"name":"canvas"' "$NVM_ALIGN_TMP/mirror.json"
grep -q '"name":"grpc-tools"' "$NVM_ALIGN_TMP/mirror.json"
grep -q '"name":"ali-usb_ctl"' "$NVM_ALIGN_TMP/mirror.json"
grep -q '"name":"playwright"' "$NVM_ALIGN_TMP/mirror.json"
grep -q '"name":"puppeteer"' "$NVM_ALIGN_TMP/mirror.json"
mirror_run use china >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
grep -q "The mirrors have been changed to 'china'." "$NVM_ALIGN_TMP/cmd.out"
grep -q "note: 14 npmrc mirror keys may trigger npm warnings" "$NVM_ALIGN_TMP/cmd.out"
grep -q "Wrote $NRM_NVM/binaries.env" "$NVM_ALIGN_TMP/cmd.err"
if grep -q 'electron_mirror=' "$NRM_HOME/.npmrc" || grep -q 'sass_binary_site=' "$NRM_HOME/.npmrc" || grep -q 'sharp_binary_host=' "$NRM_HOME/.npmrc"; then
    echo "env-backed mirrors should not be written to npmrc" >&2
    exit 1
fi
grep -q 'sqlite3_binary_host=https://cdn.npmmirror.com/binaries/sqlite3' "$NRM_HOME/.npmrc"
grep -q 'sqlite3_binary_host=https://cdn.npmmirror.com/binaries/sqlite3' "$NRM_PNPM"
grep -q 'sqlite3_binary_host "https://cdn.npmmirror.com/binaries/sqlite3"' "$NRM_HOME/.yarnrc"
grep -q "export ELECTRON_MIRROR='https://cdn.npmmirror.com/binaries/electron/'" "$NRM_NVM/binaries.env"
grep -q "export SHARP_BINARY_HOST='https://cdn.npmmirror.com/binaries/sharp'" "$NRM_NVM/binaries.env"
grep -q "export SHARP_LIBVIPS_BINARY_HOST='https://cdn.npmmirror.com/binaries/sharp-libvips'" "$NRM_NVM/binaries.env"
grep -q "export PLAYWRIGHT_DOWNLOAD_HOST='https://cdn.npmmirror.com/binaries/playwright'" "$NRM_NVM/binaries.env"
grep -q 'cypress/${version}/${platform}-${arch}/cypress.zip' "$NRM_NVM/binaries.env"
grep -q "export SASS_BINARY_SITE='https://cdn.npmmirror.com/binaries/node-sass'" "$NRM_NVM/binaries.env"
grep -q "export PUPPETEER_DOWNLOAD_HOST='https://cdn.npmmirror.com/binaries/chrome-for-testing'" "$NRM_NVM/binaries.env"
grep -q "export RE2_DOWNLOAD_SKIP_PATH='true'" "$NRM_NVM/binaries.env"
if grep -q 'npm_config_' "$NRM_NVM/binaries.env"; then
    echo "binaries.env should not set npm_config_* mirror vars" >&2
    exit 1
fi
grep -q 'canvas_binary_host=https://cdn.npmmirror.com/binaries/canvas' "$NRM_HOME/.npmrc"
grep -q 'grpc_node_binary_host_mirror=https://cdn.npmmirror.com/binaries' "$NRM_HOME/.npmrc"
grep -q 'grpc_tools_binary_host_mirror=https://cdn.npmmirror.com/binaries' "$NRM_HOME/.npmrc"
grep -q 'nodejieba_binary_host_mirror=https://cdn.npmmirror.com/binaries/nodejieba' "$NRM_HOME/.npmrc"
grep -q 'xprofiler_binary_host_mirror=https://cdn.npmmirror.com/binaries/xprofiler' "$NRM_HOME/.npmrc"
grep -q 'gdal_binary_host_mirror=https://cdn.npmmirror.com/binaries/node-gdal-async' "$NRM_HOME/.npmrc"
grep -q 'zmq_binary_host_mirror=https://cdn.npmmirror.com/binaries/ali-zeromq' "$NRM_HOME/.npmrc"
grep -q 'usb_ctrl_binary_host_mirror=https://cdn.npmmirror.com/binaries/ali-usb_ctl' "$NRM_HOME/.npmrc"
mirror_run ls >"$NVM_ALIGN_TMP/cmd.out"
grep -q 'sqlite3 https://cdn.npmmirror.com/binaries/sqlite3 npmrc' "$NVM_ALIGN_TMP/cmd.out"
grep -q 'electron https://cdn.npmmirror.com/binaries/electron/' "$NVM_ALIGN_TMP/cmd.out"
if grep -q 'electron https://cdn.npmmirror.com/binaries/electron/ npmrc' "$NVM_ALIGN_TMP/cmd.out"; then
    echo "electron should not be tagged npmrc" >&2
    exit 1
fi
MIGRATE_HOME="$NVM_ALIGN_TMP/migrate-home"
mkdir -p "$MIGRATE_HOME/.nvm"
cat > "$MIGRATE_HOME/.npmrc" <<'EOF'
always-auth=true
# nvm binaries begin
electron_mirror=https://cdn.npmmirror.com/binaries/electron/
sass_binary_site=https://cdn.npmmirror.com/binaries/node-sass/
# nvm binaries end
EOF
env -u XDG_CONFIG_HOME HOME="$MIGRATE_HOME" NVM_DIR="$MIGRATE_HOME/.nvm" LC_ALL=C "$ZNVM_BIN" mirror use china >/dev/null
grep -q 'always-auth=true' "$MIGRATE_HOME/.npmrc"
if grep -q 'electron_mirror=' "$MIGRATE_HOME/.npmrc" || grep -q 'sass_binary_site=' "$MIGRATE_HOME/.npmrc"; then
    echo "mirror use china did not migrate env-backed keys out of npmrc" >&2
    cat "$MIGRATE_HOME/.npmrc" >&2
    exit 1
fi
grep -q 'sqlite3_binary_host=' "$MIGRATE_HOME/.npmrc"
grep -q "export ELECTRON_MIRROR=" "$MIGRATE_HOME/.nvm/binaries.env"
echo "  Testing npm 11 mirror warnings..."
NPM11_PREFIX="$NVM_ALIGN_TMP/npm11-prefix"
mkdir -p "$NPM11_PREFIX"
if npm install -g npm@11 --prefix "$NPM11_PREFIX" >/dev/null 2>&1; then
    NPM11_BIN="$NPM11_PREFIX/bin/npm"
    NPM11_OUT=$(bash -c 'set -a; . "$1/.nvm/binaries.env"; set +a; export HOME="$1"; "$2" config ls 2>&1' _ "$MIGRATE_HOME" "$NPM11_BIN") || NPM11_OUT=""
    if printf '%s\n' "$NPM11_OUT" | grep -qi 'Unknown.*electron_mirror'; then
        echo "npm 11 still warns on electron_mirror after migration" >&2
        printf '%s\n' "$NPM11_OUT" >&2
        exit 1
    fi
    if printf '%s\n' "$NPM11_OUT" | grep -qi 'Unknown.*sass_binary_site\|Unknown.*sharp_binary_host\|Unknown.*sharp_libvips'; then
        echo "npm 11 still warns on env-backed mirror keys" >&2
        printf '%s\n' "$NPM11_OUT" >&2
        exit 1
    fi
else
    echo "    note: skipped npm@11 install (network or npm unavailable)"
fi
grep -q '# nvm binaries begin' "$NRM_NVM/binaries.env"
if grep -q 'znvm' "$NRM_NVM/binaries.env"; then
    echo "binaries.env mentioned znvm" >&2
    exit 1
fi
grep -q 'fund=false' "$NRM_HOME/.npmrc"
grep -q '_authToken=secret' "$NRM_HOME/.npmrc"
nrm_run scope add @company https://npm.company.example >/dev/null
nrm_run use npm >/dev/null
if grep -q 'electron_mirror=' "$NRM_HOME/.npmrc"; then
    echo "registry scope flow should not rewrite electron_mirror into npmrc" >&2
    exit 1
fi
grep -q '@company:registry=https://npm.company.example' "$NRM_HOME/.npmrc"
grep -q 'registry=https://registry.npmjs.org/' "$NRM_HOME/.npmrc"
ENV_OUT=$(env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" "$ZNVM_BIN" env)
printf '%s\n' "$ENV_OUT" | grep -q 'binaries.env'
(
    eval "$ENV_OUT"
    test "$ELECTRON_MIRROR" = "https://cdn.npmmirror.com/binaries/electron/"
)
mirror_run set playwright https://example.com/pw | grep -q "set playwright"
grep -q "export PLAYWRIGHT_DOWNLOAD_HOST='https://example.com/pw'" "$NRM_NVM/binaries.env"
grep -q "export ELECTRON_MIRROR='https://cdn.npmmirror.com/binaries/electron/'" "$NRM_NVM/binaries.env"
mirror_run ls | grep -q '^profile custom$'
mirror_run reset | grep -q "mirrors reset"
if grep -q 'electron_mirror=' "$NRM_HOME/.npmrc"; then
    echo "mirror reset left npmrc mirrors" >&2
    exit 1
fi
if grep -q 'nvm binaries' "$NRM_HOME/.npmrc" "$NRM_HOME/.yarnrc" "$NRM_PNPM"; then
    echo "mirror reset left a mirror block" >&2
    exit 1
fi
test ! -e "$NRM_NVM/binaries.env"
test ! -e "$NRM_NVM/binaries.json"
grep -q 'fund=false' "$NRM_HOME/.npmrc"
grep -q '_authToken=secret' "$NRM_HOME/.npmrc"
grep -q '@company:registry=https://npm.company.example' "$NRM_HOME/.npmrc"
grep -q 'registry=https://registry.npmjs.org/' "$NRM_HOME/.npmrc"
FAKE_CURL_DIR="$EMPTY_ROOT/fake-curl"
mkdir -p "$FAKE_CURL_DIR"
cat > "$FAKE_CURL_DIR/curl" << 'EOF'
#!/bin/sh
url=
for arg in "$@"; do
    url=$arg
done
case "$url" in
    *127.0.0.1*) exit 7 ;;
esac
if [ "${ZNVM_FAKE_CURL:-china-fast}" = "official-fast" ]; then
    case "$url" in
        *npmmirror*) echo 0.800 ;;
        *) echo 0.100 ;;
    esac
else
    case "$url" in
        *npmmirror*) echo 0.050 ;;
        *) echo 0.400 ;;
    esac
fi
exit 0
EOF
chmod +x "$FAKE_CURL_DIR/curl"
nrm_auto() {
    env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" LC_ALL=C PATH="$FAKE_CURL_DIR:/usr/bin:/bin" "$EMPTY_ROOT/nrm-bin/nrm" "$@"
}
rm -f "$NRM_NVM/mirror-latency.json"
nrm_auto test npm | grep -q '^npm 0.400s$'
nrm_auto use auto | grep -q "The registry has been changed to 'taobao'."
test "$(nrm_auto current)" = "taobao"
grep -q '@company:registry=https://npm.company.example' "$NRM_HOME/.npmrc"
ZNVM_FAKE_CURL=official-fast nrm_auto use auto | grep -q "The registry has been changed to 'taobao'."
test "$(ZNVM_FAKE_CURL=official-fast nrm_auto current)" = "taobao"
rm -f "$NRM_NVM/mirror-latency.json"
ZNVM_FAKE_CURL=official-fast nrm_auto use auto | grep -q "The registry has been changed to 'npm'."
test "$(nrm_auto current)" = "npm"
grep -q '@company:registry=https://npm.company.example' "$NRM_HOME/.npmrc"
rm -f "$NRM_NVM/mirror-latency.json"
mirror_auto() {
    env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" LC_ALL=C PATH="$FAKE_CURL_DIR:/usr/bin:/bin" "$ZNVM_BIN" mirror "$@"
}
mirror_auto test electron >"$NVM_ALIGN_TMP/cmd.out"
grep -q '^electron china 0.050s$' "$NVM_ALIGN_TMP/cmd.out"
grep -q '^electron official 0.400s$' "$NVM_ALIGN_TMP/cmd.out"
mirror_auto use auto | grep -q "The mirrors have been changed to 'auto'."
grep -q "export ELECTRON_MIRROR='https://cdn.npmmirror.com/binaries/electron/'" "$NRM_NVM/binaries.env"
grep -q '@company:registry=https://npm.company.example' "$NRM_HOME/.npmrc"
rm -f "$NRM_NVM/mirror-latency.json"
ZNVM_FAKE_CURL=official-fast mirror_auto use auto >/dev/null
if [ -f "$NRM_NVM/binaries.env" ] && grep -q ELECTRON_MIRROR "$NRM_NVM/binaries.env"; then
    echo "official-fast auto left ELECTRON_MIRROR set" >&2
    exit 1
fi
grep -q '@company:registry=https://npm.company.example' "$NRM_HOME/.npmrc"
set +e
nrm_run add auto https://example.com >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
NRM_STATUS=$?
set -e
if [[ "$NRM_STATUS" -eq 0 ]] || ! grep -q "error: auto is reserved." "$NVM_ALIGN_TMP/cmd.err"; then
    echo "FAIL add auto status=$NRM_STATUS" >&2
    exit 1
fi
set +e
nrm_run nosuch >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
NRM_STATUS=$?
set -e
if [[ "$NRM_STATUS" -eq 0 ]] || ! grep -q "nrm - registry manager" "$NVM_ALIGN_TMP/cmd.out"; then
    echo "FAIL unknown nrm status=$NRM_STATUS" >&2
    exit 1
fi
python3 - "$EMPTY_ROOT/nrm-bin/nrm" "$NRM_HOME" "$NRM_NVM" <<'PY'
import os, pty, select, subprocess, sys, time
bin_path, home, nvm_dir = sys.argv[1], sys.argv[2], sys.argv[3]
master, slave = pty.openpty()
env = os.environ.copy()
env.update({"HOME": home, "NVM_DIR": nvm_dir, "LC_ALL": "C", "PATH": "/usr/bin:/bin"})
env.pop("XDG_CONFIG_HOME", None)
env.pop("CI", None)
env.pop("NVM_NONINTERACTIVE", None)
proc = subprocess.Popen([bin_path], stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True)
os.close(slave)
data = b""
end = time.time() + 5
seen = False
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
        if b"Test and auto" in data and not seen:
            seen = True
            os.write(master, b"0\n")
    if proc.poll() is not None and seen:
        break
else:
    proc.kill()
    raise SystemExit("timeout waiting for nrm menu\n" + data.decode("utf-8", "replace"))
proc.wait(timeout=2)
os.close(master)
text = data.decode("utf-8", "replace")
if proc.returncode != 0:
    raise SystemExit(f"nrm menu exit {proc.returncode}\n{text}")
if "Install Node" in text:
    raise SystemExit(f"nrm opened the full guide\n{text}")
if "Registries" not in text or "Scopes" not in text or "Test and auto" not in text:
    raise SystemExit(f"nrm menu missing a section\n{text}")
if "Binary mirrors" in text or "Mirrors" in text:
    raise SystemExit(f"nrm menu listed download mirrors\n{text}")
print("pty nrm ok")
PY
echo -e "    ${GREEN}✓${NC} nrm command OK"

echo "  Testing nvm and nrm commands stay separate..."
SPLIT_HOME="$NVM_ALIGN_TMP/split-home"
SPLIT_NVM="$SPLIT_HOME/.nvm"
mkdir -p "$SPLIT_NVM/versions/node/v22.23.4/bin" "$SPLIT_HOME/bin" "$SPLIT_HOME/.bashrc.d"
printf '#!/bin/sh\nprintf "v22.23.4\\n"\n' > "$SPLIT_NVM/versions/node/v22.23.4/bin/node"
chmod +x "$SPLIT_NVM/versions/node/v22.23.4/bin/node"
cp "$ZNVM_BIN" "$SPLIT_HOME/bin/nvm"
ln -s nvm "$SPLIT_HOME/bin/nrm"
touch "$SPLIT_HOME/.bashrc"
set +e
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nvm" use 22 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
SPLIT_STATUS=$?
set -e
SPLIT_OUT=$(cat "$NVM_ALIGN_TMP/cmd.out" || true)
SPLIT_ERR=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$SPLIT_STATUS" -ne 0 ]] || ! printf '%s\n' "$SPLIT_ERR" | grep -q "Using v22.23.4"; then
    echo "FAIL nvm use 22 status=$SPLIT_STATUS stdout=$(printf %q "$SPLIT_OUT") stderr=$(printf %q "$SPLIT_ERR")" >&2
    exit 1
fi
if printf '%s\n' "$SPLIT_OUT" "$SPLIT_ERR" | grep -q "The registry has been changed"; then
    echo "nvm use 22 changed a registry" >&2
    exit 1
fi
printf '%s\n' "$SPLIT_OUT" | grep -q 'export PATH='
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nvm" ls >"$NVM_ALIGN_TMP/nvm-ls.out"
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nrm" ls >"$NVM_ALIGN_TMP/nrm-ls.out"
grep -q "v22.23.4" "$NVM_ALIGN_TMP/nvm-ls.out"
if grep -q "registry.npmjs.org" "$NVM_ALIGN_TMP/nvm-ls.out"; then
    echo "nvm ls printed registries" >&2
    exit 1
fi
grep -q "taobao https://registry.npmmirror.com/" "$NVM_ALIGN_TMP/nrm-ls.out"
if grep -q "v22.23.4" "$NVM_ALIGN_TMP/nrm-ls.out"; then
    echo "nrm ls printed Node versions" >&2
    exit 1
fi
if cmp -s "$NVM_ALIGN_TMP/nvm-ls.out" "$NVM_ALIGN_TMP/nrm-ls.out"; then
    echo "nvm ls and nrm ls printed the same text" >&2
    exit 1
fi
set +e
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nvm" use taobao >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
SPLIT_STATUS=$?
set -e
SPLIT_ERR=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$SPLIT_STATUS" -eq 0 ]] || ! printf '%s\n' "$SPLIT_ERR" | grep -q "not installed"; then
    echo "FAIL nvm use taobao status=$SPLIT_STATUS stderr=$(printf %q "$SPLIT_ERR")" >&2
    exit 1
fi
set +e
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nvm" binary ls >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
SPLIT_STATUS=$?
set -e
SPLIT_ERR=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$SPLIT_STATUS" -eq 0 ]] || ! printf '%s\n' "$SPLIT_ERR" | grep -q "Unknown command: binary"; then
    echo "FAIL nvm binary status=$SPLIT_STATUS stderr=$(printf %q "$SPLIT_ERR")" >&2
    exit 1
fi
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nvm" mirror ls >"$NVM_ALIGN_TMP/cmd.out"
grep -q '^profile official$' "$NVM_ALIGN_TMP/cmd.out"
grep -q '  electron (unset)' "$NVM_ALIGN_TMP/cmd.out"
set +e
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nrm" mirror ls >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
SPLIT_STATUS=$?
set -e
if [[ "$SPLIT_STATUS" -eq 0 ]] || ! grep -q "nrm - registry manager" "$NVM_ALIGN_TMP/cmd.out"; then
    echo "FAIL nrm mirror status=$SPLIT_STATUS" >&2
    exit 1
fi
set +e
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nrm" binary ls >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
SPLIT_STATUS=$?
set -e
if [[ "$SPLIT_STATUS" -eq 0 ]] || ! grep -q "nrm - registry manager" "$NVM_ALIGN_TMP/cmd.out"; then
    echo "FAIL nrm binary status=$SPLIT_STATUS" >&2
    exit 1
fi
set +e
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nvm" use auto >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
SPLIT_STATUS=$?
set -e
SPLIT_OUT=$(cat "$NVM_ALIGN_TMP/cmd.out" "$NVM_ALIGN_TMP/cmd.err" || true)
if printf '%s\n' "$SPLIT_OUT" | grep -q "The registry has been changed"; then
    echo "nvm use auto changed a registry" >&2
    exit 1
fi
set +e
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nrm" use 22 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
SPLIT_STATUS=$?
set -e
SPLIT_ERR=$(cat "$NVM_ALIGN_TMP/cmd.err" || true)
if [[ "$SPLIT_STATUS" -eq 0 ]] || ! printf '%s\n' "$SPLIT_ERR" | grep -q "22 is not a registry"; then
    echo "FAIL nrm use 22 status=$SPLIT_STATUS stderr=$(printf %q "$SPLIT_ERR")" >&2
    exit 1
fi
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nrm" use taobao >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
grep -q "The registry has been changed to 'taobao'." "$NVM_ALIGN_TMP/cmd.out"
if grep -q "Using v22" "$NVM_ALIGN_TMP/cmd.out" "$NVM_ALIGN_TMP/cmd.err"; then
    echo "nrm use taobao switched Node" >&2
    exit 1
fi
grep -q 'registry=https://registry.npmmirror.com/' "$SPLIT_HOME/.npmrc"
set +e
env -u XDG_CONFIG_HOME -u ZNVM_DIR HOME="$SPLIT_HOME" NVM_DIR="$SPLIT_NVM" PATH="/usr/bin:/bin" \
    "$SPLIT_HOME/bin/nvm" add local http://127.0.0.1:1 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
SPLIT_STATUS=$?
set -e
if [[ "$SPLIT_STATUS" -eq 0 ]]; then
    echo "nvm add was accepted" >&2
    exit 1
fi
grep -q "Unknown command: add" "$NVM_ALIGN_TMP/cmd.err"
env -i \
    HOME="$SPLIT_HOME" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/bash" \
    ZNVM_BIN_SRC="$ZNVM_BIN" \
    bash ./install-as-nvm.sh >/dev/null
if grep -q 'nrm()' "$SPLIT_NVM/nvm.sh"; then
    echo "nvm.sh defined an nrm function" >&2
    exit 1
fi
bash -c '
    set -e
    export HOME="$1"
    export PATH="/usr/bin:/bin"
    # shellcheck disable=SC1091
    . "$1/.nvm/nvm.sh"
    if [ "$(type -t nvm)" != "function" ]; then
        echo "nvm is not a shell function: $(type -t nvm)" >&2
        exit 1
    fi
    if [ "$(type -t nrm)" = "function" ]; then
        echo "nvm.sh intercepted nrm" >&2
        exit 1
    fi
    if [ "$(type -t nrm)" != "file" ]; then
        echo "nrm is not the binary: $(type -t nrm 2>&1)" >&2
        exit 1
    fi
    nvm use 22 >/dev/null
    cur=$(nvm current)
    if [ "$cur" != "v22.23.4" ]; then
        echo "shell nvm use 22 current=$cur" >&2
        exit 1
    fi
    nvm_ls=$(nvm ls)
    nrm_ls=$(nrm ls)
    printf "%s\n" "$nvm_ls" | grep -q "v22.23.4"
    if printf "%s\n" "$nvm_ls" | grep -q "registry.npmjs.org"; then
        echo "shell nvm ls printed registries" >&2
        exit 1
    fi
    printf "%s\n" "$nrm_ls" | grep -q "taobao https://registry.npmmirror.com/"
    if printf "%s\n" "$nrm_ls" | grep -q "v22.23.4"; then
        echo "shell nrm ls printed Node versions" >&2
        exit 1
    fi
    nvm mirror ls | grep -q "^profile "
    if nrm mirror ls >/dev/null 2>&1; then
        echo "shell nrm mirror was accepted" >&2
        exit 1
    fi
    if nrm binary ls >/dev/null 2>&1; then
        echo "shell nrm binary was accepted" >&2
        exit 1
    fi
    nrm use npm >/dev/null
    reg=$(nrm current)
    if [ "$reg" != "npm" ]; then
        echo "shell nrm current=$reg" >&2
        exit 1
    fi
    cur=$(nvm current)
    if [ "$cur" != "v22.23.4" ]; then
        echo "nrm use changed the Node version: $cur" >&2
        exit 1
    fi
' _ "$SPLIT_HOME"
echo -e "    ${GREEN}✓${NC} nvm and nrm commands stay separate"

echo "  Testing --llm output..."
"$ZNVM_BIN" --llm >"$NVM_ALIGN_TMP/llm-nvm.out"
cmp -s "$NVM_ALIGN_TMP/llm-nvm.out" skills/znvm/SKILL.md
"$EMPTY_ROOT/nrm-bin/nrm" --llm >"$NVM_ALIGN_TMP/llm-nrm.out"
cmp -s "$NVM_ALIGN_TMP/llm-nrm.out" skills/znvm/SKILL.md
cmp -s "$NVM_ALIGN_TMP/llm-nvm.out" "$NVM_ALIGN_TMP/llm-nrm.out"
echo -e "    ${GREEN}✓${NC} --llm matches skills/znvm/SKILL.md"
REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
bash "$REPO_ROOT/scripts/sync-llm-txt.sh"
bash "$REPO_ROOT/scripts/sync-install-sh.sh"

echo "  Testing --json output..."
mkdir -p "$ALIGN_ROOT/empty-bin" "$ALIGN_ROOT/cache" "$ALIGN_ROOT/fail-curl" \
    "$ALIGN_ROOT/versions/v18.0.0/bin"
printf '#!/bin/sh\nprintf "v18 %%s\\n" "$*"\n' > "$ALIGN_ROOT/versions/v18.0.0/bin/node"
chmod +x "$ALIGN_ROOT/versions/v18.0.0/bin/node"
printf '#!/bin/sh\nexit 1\n' > "$ALIGN_ROOT/fail-curl/curl"
chmod +x "$ALIGN_ROOT/fail-curl/curl"
cat > "$ALIGN_ROOT/cache/index.json" << 'EOF'
[{"version":"v22.23.4","files":["linux-x64","linux-arm64","osx-x64-tar","osx-arm64-tar"],"lts":false},{"version":"v20.11.0","files":["linux-x64","linux-arm64","osx-x64-tar","osx-arm64-tar"],"lts":"Iron"}]
EOF
json_nvm() {
    env -u ZNVM_DIR -u CI -u NVM_NONINTERACTIVE NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="$ALIGN_ROOT/empty-bin" NO_COLOR=1 "$ALIGN_ROOT/bin/nvm" "$@"
}
json_nvm ls --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d=={"current":None,"versions":[{"version":"v18.0.0","current":False},{"version":"v20.11.0","current":False}],"aliases":[{"name":"default","target":"18"}]}' "$NVM_ALIGN_TMP/cmd.out"
json_nvm ls --no-alias --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["aliases"]==[] and len(d["versions"])==2' "$NVM_ALIGN_TMP/cmd.out"
TEXT_LS=$(json_nvm ls)
case "$TEXT_LS" in *$'\033'*) echo "ls emitted a color sequence" >&2; exit 1 ;; esac
set +e
json_nvm ls 99 --json >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
JSON_STATUS=$?
set -e
test "$JSON_STATUS" -eq 3
test ! -s "$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d=={"error":"N/A","exit":3}' "$NVM_ALIGN_TMP/cmd.err"
set +e
json_nvm ls 99 >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
JSON_STATUS=$?
set -e
test "$JSON_STATUS" -eq 3
test "$(cat "$NVM_ALIGN_TMP/cmd.out")" = "N/A"
test ! -s "$NVM_ALIGN_TMP/cmd.err"
WHICH=$(json_nvm which 20)
json_nvm which --json 20 >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["version"]=="v20.11.0" and d["path"]==sys.argv[2]' "$NVM_ALIGN_TMP/cmd.out" "$WHICH"
test "$(json_nvm current --json)" = '{"version":"none"}'
test "$(json_nvm version --json)" = '{"version":"none"}'
test "$(json_nvm --version --json)" = '{"version":"v2.9.2"}'
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" "$ALIGN_BIN" version --json)" = '{"version":"v2.9.2"}'
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="$ALIGN_ROOT/fail-curl:$ALIGN_ROOT/empty-bin" "$ALIGN_ROOT/bin/nvm" ls-remote --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d=={"versions":[{"version":"v20.11.0","lts":"Iron"},{"version":"v22.23.4","lts":None}]}' "$NVM_ALIGN_TMP/cmd.out"
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="$ALIGN_ROOT/fail-curl:$ALIGN_ROOT/empty-bin" "$ALIGN_ROOT/bin/nvm" ls-remote --lts --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d=={"versions":[{"version":"v20.11.0","lts":"Iron"}]}' "$NVM_ALIGN_TMP/cmd.out"
set +e
json_nvm ls -- --json >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
JSON_STATUS=$?
set -e
test "$JSON_STATUS" -eq 3
test "$(cat "$NVM_ALIGN_TMP/cmd.out")" = "N/A"
set +e
json_nvm install --json >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
JSON_STATUS=$?
set -e
test "$JSON_STATUS" -eq 1
test ! -s "$NVM_ALIGN_TMP/cmd.out"
grep -q 'not supported for this command' "$NVM_ALIGN_TMP/cmd.err"
set +e
json_nvm --json >"$NVM_ALIGN_TMP/cmd.out" 2>"$NVM_ALIGN_TMP/cmd.err"
JSON_STATUS=$?
set -e
test "$JSON_STATUS" -eq 1
grep -q 'needs a command' "$NVM_ALIGN_TMP/cmd.err"
json_nvm help | grep -q 'NVM_LANG'
nrm_run --version --json | grep -q '"version":"v2.9.2"'
nrm_run ls --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); npm=[x for x in d["registries"] if x["name"]=="npm"][0]; tao=[x for x in d["registries"] if x["name"]=="taobao"][0]; assert npm["current"] is True and tao["current"] is False and tao["url"].startswith("https://registry.npmmirror.com")' "$NVM_ALIGN_TMP/cmd.out"
nrm_run current --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["name"]=="npm" and d["url"].startswith("https://registry.npmjs.org")' "$NVM_ALIGN_TMP/cmd.out"
test "$(nrm_run current -u)" = "https://registry.npmjs.org/"
nrm_run scope ls --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d=={"scopes":[{"scope":"@company","url":"https://npm.company.example"}]}' "$NVM_ALIGN_TMP/cmd.out"
env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" LC_ALL=C PATH="$FAKE_CURL_DIR:/usr/bin:/bin" "$EMPTY_ROOT/nrm-bin/nrm" test npm --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d=={"registries":[{"name":"npm","ok":True,"seconds":"0.400"}]}' "$NVM_ALIGN_TMP/cmd.out"
mirror_run reset >/dev/null
mirror_run ls --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); e=[x for x in d["mirrors"] if x["name"]=="electron"][0]; p=[x for x in d["mirrors"] if x["name"]=="playwright"][0]; s=[x for x in d["mirrors"] if x["name"]=="sqlite3"][0]; assert d["profile"]=="official" and e["url"] is None and p["url"] is None and s["url"] is None and len(d["mirrors"])==35' "$NVM_ALIGN_TMP/cmd.out"
env -u XDG_CONFIG_HOME HOME="$NRM_HOME" NVM_DIR="$NRM_NVM" LC_ALL=C PATH="$FAKE_CURL_DIR:/usr/bin:/bin" "$ZNVM_BIN" mirror test electron --json >"$NVM_ALIGN_TMP/cmd.out"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d=={"mirrors":[{"name":"electron","china":{"ok":True,"seconds":"0.050"},"official":{"ok":True,"seconds":"0.400"}}]}' "$NVM_ALIGN_TMP/cmd.out"
echo -e "    ${GREEN}✓${NC} --json output OK"

echo ""
echo -e "${GREEN}=== All tests passed! ===${NC}"

