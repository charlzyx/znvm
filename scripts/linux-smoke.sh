#!/usr/bin/env bash
# End-to-end smoke test on Linux using a fresh HOME and the install-as-nvm path.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
NODE_VERSION="${SMOKE_NODE_VERSION:-22}"
USE_PRODUCTION_INSTALL="${USE_PRODUCTION_INSTALL:-0}"

if [ "$USE_PRODUCTION_INSTALL" = "1" ]; then
    INSTALL_CMD=(bash -c 'curl -fsSL https://znvm.dev/install.sh | bash')
else
    ZNVM_BIN="${ZNVM_BIN:-$ROOT/zig-out/bin/znvm}"
    if [ ! -x "$ZNVM_BIN" ]; then
        echo "linux-smoke: missing binary at $ZNVM_BIN (run zig build first)" >&2
        exit 1
    fi
    INSTALL_CMD=(env ZNVM_BIN_SRC="$ZNVM_BIN" bash "$ROOT/install-as-nvm.sh")
fi

SMOKE_HOME="$(mktemp -d)"
trap 'rm -rf "$SMOKE_HOME"' EXIT

export HOME="$SMOKE_HOME"
export PATH="/usr/bin:/bin"
export SHELL="/bin/bash"

"${INSTALL_CMD[@]}" >/dev/null

NVM_DIR="$HOME/.nvm"
export NVM_DIR
# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"

nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
node -v
npm -v
nvm ls
nvm current
nvm alias default "$NODE_VERSION"
nvm exec "$NODE_VERSION" node -e 'process.stdout.write("exec-ok\n")' | grep -q exec-ok
nrm ls | head -1
nrm current -u | grep -q '^https://'
nvm mirror ls | grep -q '^profile '
test "$(nvm --version --json | jq -r .version)" = "$(nvm --version)"
test "$(nvm current --json | jq -r .version)" != "null"

# bash: new shell picks up nvm on PATH
bash -lc "export HOME='$HOME'; export NVM_DIR='$NVM_DIR'; source '$NVM_DIR/nvm.sh'; node -v" | grep -q '^v'

if command -v zsh >/dev/null 2>&1; then
    zsh -fc "export HOME='$HOME'; export NVM_DIR='$NVM_DIR'; source '$NVM_DIR/nvm.sh'; node -v" | grep -q '^v'
fi

INSTALLED_VER="$(nvm current)"
nvm uninstall "$NODE_VERSION"
if [ -d "$NVM_DIR/versions/node/$INSTALLED_VER" ]; then
    echo "linux-smoke: uninstall left $INSTALLED_VER on disk" >&2
    exit 1
fi

echo "linux-smoke OK ($NODE_VERSION)"
