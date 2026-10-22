#!/usr/bin/env bash
# Install the nvm command.
#
# Safe to run more than once. Node versions stay in ~/.nvm/versions/node and
# are not deleted. A previous nvm.sh that is not this setup is copied once to
# nvm.sh.bak. This script does not install shell completion.

set -euo pipefail

ZNVM_VERSION="v2.4.0"
REPO_OWNER="charlzyx"
REPO_NAME="znvm"
MARKER="nvm: shell setup"

if [ -z "${HOME:-}" ]; then
    echo "HOME is not set." >&2
    exit 1
fi

NVM_COMPAT_DIR="${ZNVM_NVM_DIR:-$HOME/.nvm}"
case "$NVM_COMPAT_DIR" in
    /|"$HOME"|"")
        echo "Refusing to use '$NVM_COMPAT_DIR' as NVM_DIR." >&2
        exit 1
        ;;
esac

echo "nvm"
echo "Node versions go in ~/.nvm. Downloads use https://npmmirror.com/mirrors/node."
echo ""

shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

choose_bin_dir() {
    if [ -n "${ZNVM_INSTALL_BIN_DIR:-}" ]; then
        printf '%s\n' "$ZNVM_INSTALL_BIN_DIR"
        return
    fi

    local dir
    local IFS=':'
    # shellcheck disable=SC2086
    for dir in $PATH; do
        [ -n "$dir" ] || continue
        [ -d "$dir" ] && [ -w "$dir" ] || continue
        case "$dir" in
            "$HOME/bin"|"$HOME/.local/bin"|"$HOME/.bin"|"/usr/local/bin")
                printf '%s\n' "$dir"
                return
                ;;
        esac
    done
    printf '%s\n' "$NVM_COMPAT_DIR"
}

download_binary() {
    local dest="$1"
    local os arch target version url

    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    target=""
    if [ "$os" = "darwin" ]; then
        if [ "$arch" = "arm64" ]; then
            target="aarch64-macos"
        else
            target="x86_64-macos"
        fi
    elif [ "$os" = "linux" ]; then
        if [ "$arch" = "aarch64" ]; then
            target="aarch64-linux-musl"
        elif [ "$arch" = "x86_64" ]; then
            target="x86_64-linux-musl"
        fi
    fi

    if [ -z "$target" ]; then
        echo "error: No pre-compiled nvm binary for ${os}/${arch}." >&2
        exit 1
    fi

    if [ -n "${ZNVM_VERSION_ARG:-}" ]; then
        version="$ZNVM_VERSION_ARG"
    elif [ "$ZNVM_VERSION" != "main" ]; then
        version="$ZNVM_VERSION"
    else
        version="$(curl -fsSL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
    fi

    if [ -z "$version" ]; then
        echo "error: Could not determine which nvm version to download." >&2
        exit 1
    fi

    url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$version/znvm-$version-$target"
    echo "> Downloading nvm $version ($target)..." >&2
    if ! curl -fL --retry 3 -o "$dest" "$url"; then
        rm -f "$dest"
        echo "error: Download failed: $url" >&2
        exit 1
    fi
    chmod +x "$dest"
}

install_binary() {
    local dest_dir dest

    if [ -n "${ZNVM_BIN_SRC:-}" ]; then
        if [ ! -f "$ZNVM_BIN_SRC" ]; then
            echo "Install source does not exist: $ZNVM_BIN_SRC" >&2
            exit 1
        fi
        dest_dir="${ZNVM_INSTALL_BIN_DIR:-$NVM_COMPAT_DIR}"
        mkdir -p "$dest_dir"
        dest="$dest_dir/nvm"
        cp "$ZNVM_BIN_SRC" "$dest"
        chmod +x "$dest"
        printf '%s\n' "$dest"
        return
    fi

    if [ -n "${ZNVM_INSTALL_BIN_DIR:-}" ] && [ -x "$ZNVM_INSTALL_BIN_DIR/nvm" ]; then
        printf '%s\n' "$ZNVM_INSTALL_BIN_DIR/nvm"
        return
    fi

    dest_dir="$(choose_bin_dir)"
    mkdir -p "$dest_dir"
    dest="$dest_dir/nvm"
    if [ -x "$dest" ]; then
        echo "ok nvm is already installed at $dest" >&2
        printf '%s\n' "$dest"
        return
    fi
    download_binary "$dest"
    printf '%s\n' "$dest"
}

safe_replace() {
    local dest="$1"
    local backup="$2"
    local tmp

    tmp="$(mktemp)"
    cat > "$tmp"

    if [ -d "$dest" ]; then
        rm -f "$tmp"
        echo "Refusing to replace directory $dest" >&2
        exit 1
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ -f "$dest" ] && grep -q "$MARKER" "$dest"; then
            :
        else
            if [ ! -e "$backup" ]; then
                if [ -L "$dest" ]; then
                    cp -pL "$dest" "$backup" 2>/dev/null || cp -p "$dest" "$backup"
                else
                    cp -p "$dest" "$backup"
                fi
                echo "> Saved the previous $dest as $backup"
            else
                echo "ok Previous copy already exists at $backup"
            fi
            rm -f "$dest"
        fi
    fi

    mv "$tmp" "$dest"
    chmod 644 "$dest"
}

write_nvm_sh() {
    local nvm_exe="$1"
    local quoted_exe quoted_dir
    quoted_exe="$(shell_quote "$nvm_exe")"
    quoted_dir="$(shell_quote "$NVM_COMPAT_DIR")"
    mkdir -p "$NVM_COMPAT_DIR"

    {
        echo "# $MARKER"
        printf 'export NVM_DIR=%s\n' "$quoted_dir"
        printf 'NVM_BIN=%s\n' "$quoted_exe"
        cat <<'EOF'
if [ ! -x "$NVM_BIN" ]; then
    echo "nvm: expected binary at $NVM_BIN" >&2
    return 1 2>/dev/null || exit 1
fi
__nvm_bin_dir=$(dirname "$NVM_BIN")
case ":${PATH:-}:" in
    *":$__nvm_bin_dir:"*) ;;
    *) PATH="$__nvm_bin_dir:${PATH:-}" ;;
esac
export PATH
eval "$("$NVM_BIN" env)"
EOF
    } | safe_replace "$NVM_COMPAT_DIR/nvm.sh" "$NVM_COMPAT_DIR/nvm.sh.bak"
    echo "ok Wrote $NVM_COMPAT_DIR/nvm.sh"
}

configure_profile() {
    local profile shell_name
    if [ -n "${ZNVM_PROFILE:-}" ]; then
        profile="$ZNVM_PROFILE"
    else
        shell_name="$(basename "${SHELL:-bash}")"
        case "$shell_name" in
            bash)
                if [ -f "$HOME/.bashrc" ]; then
                    profile="$HOME/.bashrc"
                else
                    profile="$HOME/.bash_profile"
                fi
                ;;
            zsh)
                profile="$HOME/.zshrc"
                ;;
            *)
                profile="$HOME/.profile"
                ;;
        esac
    fi

    if [ -d "$profile" ]; then
        echo "Refusing to write shell config into directory $profile" >&2
        exit 1
    fi

    if [ -f "$profile" ] && grep -q 'NVM_DIR/nvm.sh' "$profile"; then
        echo "ok Shell config already loads nvm ($profile)" >&2
        printf '%s\n' "$profile"
        return
    fi

    mkdir -p "$(dirname "$profile")"
    touch "$profile"
    cat >> "$profile" <<EOF

# $MARKER
export NVM_DIR="$NVM_COMPAT_DIR"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
EOF
    echo "> Added nvm startup to $profile" >&2
    printf '%s\n' "$profile"
}

ZNVM_VERSION_ARG="${1:-}"
NVM_EXE="$(install_binary)"
if [ ! -x "$NVM_EXE" ]; then
    echo "nvm was not installed." >&2
    exit 1
fi

write_nvm_sh "$NVM_EXE"
PROFILE_PATH="$(configure_profile)"

echo ""
echo "nvm is ready."
echo "Open a new terminal, or run:"
echo "  source \"$PROFILE_PATH\""
echo ""
echo "export NVM_DIR=\"$NVM_COMPAT_DIR\""
echo "nvm install 22"
echo "nvm use 22"
echo "nvm ls"
echo ""
echo "Node versions are stored in \$NVM_DIR/versions/node."
echo "Downloads use https://npmmirror.com/mirrors/node unless NVM_NODEJS_ORG_MIRROR is set."
