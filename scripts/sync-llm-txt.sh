#!/bin/sh
# Copy skills/znvm/SKILL.md to the site files nvm --llm embeds.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
src="$root/skills/znvm/SKILL.md"
pub="$root/website/public"
dist="$root/website/dist"
mkdir -p "$pub"
cp "$src" "$pub/llm.txt"
cp "$src" "$pub/llms.txt"
cmp -s "$src" "$pub/llm.txt"
cmp -s "$src" "$pub/llms.txt"
if [ "${1:-}" = "--dist" ]; then
  cmp -s "$src" "$dist/llm.txt"
  cmp -s "$src" "$dist/llms.txt"
fi
echo "llm.txt matches skills/znvm/SKILL.md"
