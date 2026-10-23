#!/bin/sh
# Publish the nvm installer at both site URLs.
# website/public/install.sh and website/public/install-as-nvm.sh stay
# byte-identical to install-as-nvm.sh. The znvm-named install.sh is separate.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
src="$root/install-as-nvm.sh"
pub="$root/website/public"
short="$pub/install.sh"
long="$pub/install-as-nvm.sh"
mkdir -p "$pub"
cp "$src" "$short"
cp "$src" "$long"
cmp -s "$src" "$short"
cmp -s "$src" "$long"
echo "install.sh matches install-as-nvm.sh"
