#!/usr/bin/env bash
# Install znvm and present it as nvm.
#
# Safe to run more than once. Node versions stay in ~/.nvm/versions/node, the
# same tree nvm uses, and are not deleted. The previous nvm.sh and
# bash_completion are copied aside once, as *.pre-znvm, before znvm's shims
# replace them.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ZNVM_VERSION="v2.2.2"
REPO_OWNER="charlzyx"
REPO_NAME="znvm"
MARKER="znvm-nvm-shim"

if [ -z "${HOME:-}" ]; then
    echo "HOME is not set." >&2
    exit 1
fi

NVM_COMPAT_DIR="${ZNVM_NVM_DIR:-$HOME/.nvm}"
case "$NVM_COMPAT_DIR" in
    /|"$HOME"|"")
        echo "Refusing to use '$NVM_COMPAT_DIR' as the nvm compatibility directory." >&2
        exit 1
        ;;
esac

echo -e "${CYAN}${BOLD}znvm: install as nvm${NC}"
echo -e "${BLUE}The nvm command will run znvm. Node versions stay in ~/.nvm/versions/node.${NC}"
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
    printf '%s\n' "$HOME/.znvm/bin"
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
        echo -e "${RED}No pre-compiled znvm binary for ${os}/${arch}.${NC}" >&2
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
        echo -e "${RED}Could not determine which znvm version to download.${NC}" >&2
        exit 1
    fi

    url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$version/znvm-$version-$target"
    echo -e "${CYAN}=> Downloading $version ($target)...${NC}" >&2
    if ! curl -fL --retry 3 -o "$dest" "$url"; then
        rm -f "$dest"
        echo -e "${RED}Download failed: $url${NC}" >&2
        exit 1
    fi
    chmod +x "$dest"
}

install_binary() {
    local dest_dir dest

    if [ -n "${ZNVM_BIN_SRC:-}" ]; then
        if [ ! -f "$ZNVM_BIN_SRC" ]; then
            echo "ZNVM_BIN_SRC does not exist: $ZNVM_BIN_SRC" >&2
            exit 1
        fi
        dest_dir="${ZNVM_INSTALL_BIN_DIR:-$HOME/.znvm/bin}"
        mkdir -p "$dest_dir"
        dest="$dest_dir/znvm"
        cp "$ZNVM_BIN_SRC" "$dest"
        chmod +x "$dest"
        printf '%s\n' "$dest"
        return
    fi

    if [ -n "${ZNVM_INSTALL_BIN_DIR:-}" ] && [ -x "$ZNVM_INSTALL_BIN_DIR/znvm" ]; then
        printf '%s\n' "$ZNVM_INSTALL_BIN_DIR/znvm"
        return
    fi

    if command -v znvm >/dev/null 2>&1; then
        dest="$(command -v znvm)"
        if [ -x "$dest" ]; then
            echo -e "${GREEN}✔ Using existing znvm at $dest${NC}" >&2
            printf '%s\n' "$dest"
            return
        fi
    fi

    dest_dir="$(choose_bin_dir)"
    mkdir -p "$dest_dir"
    dest="$dest_dir/znvm"
    if [ -x "$dest" ]; then
        echo -e "${GREEN}✔ znvm is already installed at $dest${NC}" >&2
        printf '%s\n' "$dest"
        return
    fi
    download_binary "$dest"
    printf '%s\n' "$dest"
}

link_nvm_command() {
    local znvm_exe="$1"
    local bin_dir link

    bin_dir="$(dirname "$znvm_exe")"
    link="$bin_dir/nvm"
    if [ ! -w "$bin_dir" ]; then
        echo "Cannot create the nvm command in $bin_dir (not writable)." >&2
        exit 1
    fi

    if [ -d "$link" ] && [ ! -L "$link" ]; then
        echo "Refusing to replace directory $link" >&2
        exit 1
    fi

    if [ -L "$link" ] && [ "$(readlink "$link")" = "znvm" ]; then
        echo -e "${GREEN}✔ nvm already points at znvm${NC}"
        return
    fi

    if [ -e "$link" ] || [ -L "$link" ]; then
        if [ ! -e "$link.pre-znvm" ]; then
            mv "$link" "$link.pre-znvm"
            echo -e "${YELLOW}=> Moved existing nvm command to $link.pre-znvm${NC}"
        else
            rm -f "$link"
            echo -e "${YELLOW}=> Replacing nvm command; backup already exists at $link.pre-znvm${NC}"
        fi
    fi
    ln -s znvm "$link"
    echo -e "${GREEN}✔ Linked $link -> znvm${NC}"
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
                echo -e "${YELLOW}=> Backed up $dest to $backup${NC}"
            else
                echo -e "${GREEN}✔ Backup already exists at $backup${NC}"
            fi
            rm -f "$dest"
        fi
    fi

    mv "$tmp" "$dest"
    chmod 644 "$dest"
}

write_nvm_sh() {
    local znvm_exe="$1"
    local quoted
    quoted="$(shell_quote "$znvm_exe")"
    mkdir -p "$NVM_COMPAT_DIR"

    {
        echo "# $MARKER"
        echo "# Compatibility entry point. Sourcing this file loads znvm as nvm."
        echo "# Node versions previously installed by nvm in this directory are not modified."
        printf 'ZNVM_EXE=%s\n' "$quoted"
        cat <<'EOF'
if [ ! -x "$ZNVM_EXE" ]; then
    echo "znvm: expected binary at $ZNVM_EXE" >&2
    return 1 2>/dev/null || exit 1
fi
__znvm_bin_dir=$(dirname "$ZNVM_EXE")
case ":${PATH:-}:" in
    *":$__znvm_bin_dir:"*) ;;
    *) PATH="$__znvm_bin_dir:${PATH:-}" ;;
esac
export PATH
eval "$("$ZNVM_EXE" env)"
EOF
    } | safe_replace "$NVM_COMPAT_DIR/nvm.sh" "$NVM_COMPAT_DIR/nvm.sh.pre-znvm"
    echo -e "${GREEN}✔ Wrote $NVM_COMPAT_DIR/nvm.sh${NC}"
}

write_completion() {
    mkdir -p "$NVM_COMPAT_DIR"
    cat <<EOF | safe_replace "$NVM_COMPAT_DIR/bash_completion" "$NVM_COMPAT_DIR/bash_completion.pre-znvm"
# $MARKER
_znvm_complete() {
    local cur="\${COMP_WORDS[COMP_CWORD]}"
    if [ "\${COMP_CWORD}" -eq 1 ]; then
        COMPREPLY=( \$(compgen -W "help install use exec run ls list ls-remote list-remote current which version version-remote alias unalias uninstall rm deactivate env" -- "\$cur") )
    fi
}
complete -F _znvm_complete nvm
complete -F _znvm_complete znvm
EOF
    echo -e "${GREEN}✔ Wrote $NVM_COMPAT_DIR/bash_completion${NC}"
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

    if [ -f "$profile" ] && grep -Eq 'nvm\.sh|znvm env|znvm-nvm-shim' "$profile"; then
        echo -e "${GREEN}✔ Shell config already loads nvm or znvm ($profile)${NC}" >&2
        printf '%s\n' "$profile"
        return
    fi

    mkdir -p "$(dirname "$profile")"
    touch "$profile"
    cat >> "$profile" <<EOF

# $MARKER
export NVM_DIR="$NVM_COMPAT_DIR"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && . "\$NVM_DIR/bash_completion"
EOF
    echo -e "${CYAN}=> Added nvm startup to $profile${NC}" >&2
    printf '%s\n' "$profile"
}

ZNVM_VERSION_ARG="${1:-}"
ZNVM_EXE="$(install_binary)"
if [ ! -x "$ZNVM_EXE" ]; then
    echo "znvm binary was not installed." >&2
    exit 1
fi

link_nvm_command "$ZNVM_EXE"
write_nvm_sh "$ZNVM_EXE"
write_completion
PROFILE_PATH="$(configure_profile)"

echo ""
echo -e "${GREEN}${BOLD}nvm now runs znvm.${NC}"
echo -e "${CYAN}Open a new terminal, or run:${NC}"
echo -e "  ${BOLD}source \"$PROFILE_PATH\"${NC}"
echo ""
echo -e "${YELLOW}Node versions stay in $NVM_COMPAT_DIR/versions/node, the same tree nvm uses.${NC}"
echo -e "${YELLOW}Existing installs there are kept. The znvm binary itself lives next to the nvm command.${NC}"
echo -e "${YELLOW}Restore the previous nvm startup files from *.pre-znvm in $NVM_COMPAT_DIR if you need them.${NC}"
