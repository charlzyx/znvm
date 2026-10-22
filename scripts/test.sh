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
env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" alias default 18 >/dev/null
set +e
DEFAULT_OUT=$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" default 2>"$NVM_ALIGN_TMP/default.err")
DEFAULT_STATUS=$?
set -e
if [[ "$DEFAULT_STATUS" -ne 0 || "$DEFAULT_OUT" != "18" ]]; then
    echo "default status=$DEFAULT_STATUS stdout=[$DEFAULT_OUT] stderr=[$(cat "$NVM_ALIGN_TMP/default.err")]" >&2
    echo "alias file=[$([ -f "$ALIGN_ROOT/alias/default" ] && cat "$ALIGN_ROOT/alias/default")] legacy=[$([ -f "$ALIGN_ROOT/default" ] && cat "$ALIGN_ROOT/default")]" >&2
    exit 1
fi
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" version default)" = "v18.0.0"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" which 20)" = "$ALIGN_ROOT/versions/node/v20.11.0/bin/node"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" which 18)" = "$ALIGN_ROOT/versions/v18.0.0/bin/node"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_BIN" current)" = "none"
test "$(env -u ZNVM_DIR NVM_DIR="$ALIGN_ROOT" HOME="$NVM_ALIGN_TMP/home" PATH="/usr/bin:/bin" "$ALIGN_ROOT/bin/nvm" version)" = "none"
test "$(env -u NVM_DIR ZNVM_DIR="$ALIGN_ROOT" "$ALIGN_ROOT/bin/nvm" --version)" = "v2.4.0"
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
    test "$(nvm --version)" = "v2.4.0"
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
    test "$(nvm --version)" = "v2.4.0"
    test "$(nvm version)" = "none"
    test "$(nvm current)" = "none"
    test -z "$(type znvm 2>/dev/null || true)"
' _ "$INSTALL_HOME"
echo -e "    ${GREEN}✓${NC} install-as-nvm.sh OK"

echo "  Testing interactive guide..."
GUIDE_BIN="$ZNVM_BIN"
set +e
GUIDE_OUT=$(env -u NVM_DIR -u ZNVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" </dev/null 2>&1)
GUIDE_STATUS=$?
set -e
test "$GUIDE_STATUS" -eq 1
printf '%s\n' "$GUIDE_OUT" | grep -q "interactive guide needs a terminal"
set +e
GUIDE_OUT=$(env -u NVM_DIR -u ZNVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" guide </dev/null 2>&1)
GUIDE_STATUS=$?
set -e
test "$GUIDE_STATUS" -eq 1
printf '%s\n' "$GUIDE_OUT" | grep -q "interactive guide needs a terminal"
set +e
GUIDE_OUT=$(env -u NVM_DIR -u ZNVM_DIR HOME="$EMPTY_ROOT/home" LC_ALL=C "$GUIDE_BIN" interactive </dev/null 2>&1)
GUIDE_STATUS=$?
set -e
test "$GUIDE_STATUS" -eq 1
printf '%s\n' "$GUIDE_OUT" | grep -q "interactive guide needs a terminal"
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
print("pty guide ok")
PY
echo -e "    ${GREEN}✓${NC} interactive guide OK"

echo ""
echo -e "${GREEN}=== All tests passed! ===${NC}"

