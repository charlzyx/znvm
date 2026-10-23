#!/bin/sh
# Install skills/znvm with the npm skills CLI and require a byte match.
set -eu
export DISABLE_TELEMETRY=1
export DO_NOT_TRACK=1
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
npm init -y >/dev/null
npx --yes skills@1.7.4 add "$root" --skill znvm -a cursor --copy -y
cmp -s "$work/.agents/skills/znvm/SKILL.md" "$root/skills/znvm/SKILL.md"
echo "npx skills add installed skills/znvm/SKILL.md"
