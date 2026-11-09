#!/usr/bin/env bash
# Bump public installer/site files to VERSION (e.g. v2.10.2). Used by release workflow.
set -euo pipefail
VERSION="${VERSION:?set VERSION to vX.Y.Z}"
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

replace_version() {
  local file=$1 pattern=$2
  if ! grep -q "$pattern" "$file"; then
    echo "promote: expected version marker missing in $file" >&2
    exit 1
  fi
  sed -i "s|$pattern|$3|g" "$file"
}

for script in install.sh install-as-nvm.sh; do
  replace_version "$script" '^ZNVM_VERSION="v[0-9][^"]*"$' "ZNVM_VERSION=\"$VERSION\""
done

replace_version website/src/components/hero.tsx \
  'const version = "v[0-9][^"]*";' \
  "const version = \"$VERSION\";"

skill=skills/znvm/SKILL.md
if ! grep -q 'are the tool: `{"version":"v' "$skill"; then
  echo "promote: skill tool-version example missing" >&2
  exit 1
fi
sed -i "s/are the tool: \`{\"version\":\"v[^\"]*\"}\`/are the tool: \`{\"version\":\"$VERSION\"}\`/g" "$skill"

bash scripts/sync-install-sh.sh
bash scripts/sync-llm-txt.sh

python3 - <<'PYTHON'
import os
import runpy
release = runpy.run_path("scripts/release-request.py")
release["verify_public_versions"](allowed=(os.environ["VERSION"],))
PYTHON

echo "promote: public files at $VERSION"
