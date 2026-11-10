#!/usr/bin/env bash
# Capture key-by-key guide pty transcripts for PR evidence (isolated NVM_DIR).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/zig-out/bin/znvm"
ART="${ARTIFACT_DIR:-/opt/cursor/artifacts}"
mkdir -p "$ART"
OUT="$ART/guide-pty-transcripts.txt"
: >"$OUT"

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
export LC_ALL=C LANG=C NVM_LANG=en

python3 - "$BIN" "$NVM_DIR" "$HOME" "$OUT" <<'PY'
import os, pty, select, subprocess, sys, time

bin_path, nvm_dir, home, out_path = sys.argv[1:5]

def run_pty(label, args, env, sends, timeout=6):
    master, slave = pty.openpty()
    proc = subprocess.Popen(
        args, stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True,
    )
    os.close(slave)
    data = b""
    for item in sends:
        if isinstance(item, tuple):
            time.sleep(item[1])
            continue
        os.write(master, item.encode("latin-1") if isinstance(item, str) else item)
        time.sleep(0.08)
    end = time.time() + timeout
    while time.time() < end:
        r, _, _ = select.select([master], [], [], 0.15)
        if master in r:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            data += chunk
        if proc.poll() is not None:
            break
    try:
        os.write(master, b"q")
    except OSError:
        pass
    time.sleep(0.3)
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
    os.close(master)
    text = data.decode("utf-8", "replace")
    with open(out_path, "a", encoding="utf-8") as fh:
        fh.write(f"\n=== {label} ===\n")
        fh.write("keys: " + repr(sends) + "\n")
        fh.write(text)
        fh.write("\n")
    print(f"wrote {label}")

base = {
    "LC_ALL": "C", "LANG": "C", "NVM_LANG": "en",
    "HOME": home, "PATH": "/usr/bin:/bin", "NVM_DIR": nvm_dir,
}
run_pty("bare_switch", [bin_path], base, ["2", "\r", "\r", "0", "\r"])
run_pty("esc_on_use_prompt", [bin_path], base, ["2", "\r", "3", "\r", "\x1b", "\r"])
run_pty("manage_ls", [bin_path], base, ["4", "\r", "0", "\r", "0", "\r"])
PY

echo "Transcript: $OUT"
cat "$OUT" | head -80
