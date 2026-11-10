#!/usr/bin/env bash
# Interactive guide pty smoke for CI or local runs (isolated NVM_DIR).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/zig-out/bin/znvm"
if [[ ! -x "$BIN" ]]; then
  (cd "$ROOT" && zig build)
  BIN="${ROOT}/zig-out/bin/znvm"
fi
export NVM_DIR="${NVM_DIR:-/tmp/znvm-pty-$$}"
export HOME="${HOME:-/tmp/znvm-home-$$}"
rm -rf "$NVM_DIR" "$HOME"
mkdir -p "$NVM_DIR/versions/node" "$HOME"
for v in v18.20.4 v20.18.0 v22.11.0; do
  mkdir -p "$NVM_DIR/versions/node/$v/bin"
  printf '#!/bin/sh\necho %s\n' "$v" >"$NVM_DIR/versions/node/$v/bin/node"
  chmod +x "$NVM_DIR/versions/node/$v/bin/node"
done
printf '22.11.0\n' >"$HOME/.nvmrc"
export PATH="/usr/bin:/bin"

run_keys() {
  local label="$1"
  local keys="$2"
  local out
  out="$(mktemp)"
  echo "=== $label ===" | tee -a "$out"
  script -q -c "python3 - \"$BIN\" <<'PY'
import sys, time, pty, os
exe = sys.argv[1]
keys = \"\"\"$keys\"\"\"
os.environ['NVM_DIR'] = os.environ.get('NVM_DIR', '')
os.environ['HOME'] = os.environ.get('HOME', '')
master, slave = pty.openpty()
pid = os.fork()
if pid == 0:
    os.setsid()
    os.dup2(slave, 0)
    os.dup2(slave, 1)
    os.dup2(slave, 2)
    os.execl(exe, exe, 'guide')
    raise SystemExit(1)
time.sleep(0.4)
for ch in keys:
    if ch == '\\n':
        os.write(master, b'\\r')
    else:
        os.write(master, ch.encode())
    time.sleep(0.08)
time.sleep(0.6)
try:
    os.write(master, b'q')
except OSError:
    pass
time.sleep(0.3)
os.kill(pid, 15)
PY
" /dev/null 2>&1 | tee -a "$out" || true
  cat "$out"
  rm -f "$out"
}

run_keys "bare_binary_switch" "2\\n\\n\\n"
run_keys "bare_binary_esc_on_prompt" "2\\n3\\n\\x1b\\n"
run_keys "bare_binary_uninstall_n" "5\\n2\\n\\n n"

echo "guide-pty-audit: done"
