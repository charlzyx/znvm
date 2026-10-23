#!/usr/bin/env bash
# Install the nvm command.
#
# Safe to run more than once. An existing nvm binary is replaced when its
# --version differs from this release. The previous file is kept as nvm.bak.
# Node versions stay in ~/.nvm/versions/node and are not deleted. A previous
# nvm.sh that is not this setup is copied once to nvm.sh.bak. This script does
# not install shell completion.

set -euo pipefail

ZNVM_VERSION="v2.9.3"
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

if [ "${1:-}" != "--uninstall" ]; then
    echo "nvm"
fi

profile_display() {
    case "$1" in
        "$HOME"/*) printf '~/%s\n' "${1#"$HOME"/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

shell_lang() {
    if [ -n "${NVM_LANG:-}" ]; then
        case "$NVM_LANG" in
            zh|zh_*) printf 'zh\n'; return ;;
            en|en_*) printf 'en\n'; return ;;
        esac
    fi
    local loc="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    case "$loc" in
        zh*) printf 'zh\n' ;;
        *) printf 'en\n' ;;
    esac
}

INSTALL_MSG_LANG=""

install_lang() {
    if [ -n "$INSTALL_MSG_LANG" ]; then
        printf '%s' "$INSTALL_MSG_LANG"
        return
    fi
    if [ -n "${NVM_EXE:-}" ] && [ -x "$NVM_EXE" ]; then
        INSTALL_MSG_LANG="$(NVM_DIR="${NVM_COMPAT_DIR}" "$NVM_EXE" lang 2>/dev/null || true)"
    fi
    if [ -z "$INSTALL_MSG_LANG" ]; then
        INSTALL_MSG_LANG="$(shell_lang)"
    fi
    printf '%s' "$INSTALL_MSG_LANG"
}

install_msg() {
    local key="$1"
    shift
    case "$(install_lang)" in
        zh)
            case "$key" in
                downloading) printf '正在下载 nvm %s (%s)...\n' "$1" "$2" >&2 ;;
                download_failed) printf '下载失败: %s\n' "$1" >&2 ;;
                version_fallback) printf '使用 %s（%s 尚未发布）\n' "$1" "$2" >&2 ;;
                saved_backup) printf '已备份 %s -> %s\n' "$1" "$2" >&2 ;;
                upgraded) printf '已升级 nvm %s -> %s\n' "$1" "$2" >&2 ;;
                wrote_nvm_sh) printf '已写入 %s\n' "$1" >&2 ;;
                added_profile) printf '已写入 %s\n' "$1" >&2 ;;
                nrm_link_exists) printf 'nrm 链接已存在: %s\n' "$1" >&2 ;;
                nrm_link_blocked) printf '未改动 %s；移走后重新安装可在此链接 nrm\n' "$1" >&2 ;;
                nrm_other) printf '另有 nrm: %s（未删除）\n' "$1" >&2 ;;
                nrm_path_hint) printf '新 shell 会优先使用 %s 作为 nrm\n' "$1" >&2 ;;
                *) printf '%s\n' "$*" >&2 ;;
            esac
            ;;
        *)
            case "$key" in
                downloading) printf 'Downloading nvm %s (%s)...\n' "$1" "$2" >&2 ;;
                download_failed) printf 'Download failed: %s\n' "$1" >&2 ;;
                version_fallback) printf 'Using %s (%s is not published yet)\n' "$1" "$2" >&2 ;;
                saved_backup) printf 'Saved %s as %s\n' "$1" "$2" >&2 ;;
                upgraded) printf 'Upgraded nvm %s -> %s\n' "$1" "$2" >&2 ;;
                wrote_nvm_sh) printf 'Wrote %s\n' "$1" >&2 ;;
                added_profile) printf 'Wrote %s\n' "$1" >&2 ;;
                nrm_link_exists) printf 'nrm already linked at %s\n' "$1" >&2 ;;
                nrm_link_blocked) printf 'Left %s unchanged; move it and reinstall to link nrm here\n' "$1" >&2 ;;
                nrm_other) printf 'Another nrm at %s (not removed)\n' "$1" >&2 ;;
                nrm_path_hint) printf 'A new shell prefers %s as nrm\n' "$1" >&2 ;;
                *) printf '%s\n' "$*" >&2 ;;
            esac
            ;;
    esac
}

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

installed_version() {
    local exe="$1"
    local out
    out=""
    if [ -x "$exe" ] && [ ! -d "$exe" ]; then
        # bash 3.2 exits the shell when a command substitution fails under set -e.
        set +e
        out=$("$exe" --version 2>/dev/null | head -n 1)
        set -e
    fi
    printf '%s\n' "$out" | tr -d '\r'
}

release_asset_exists() {
    local version="$1"
    local target="$2"
    local url
    url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$version/znvm-$version-$target"
    curl -fsSIL -o /dev/null "$url" 2>/dev/null
}

find_published_version() {
    local target="$1"
    local prefer="$2"
    local tags tag
    if [ -n "$prefer" ] && release_asset_exists "$prefer" "$target"; then
        printf '%s\n' "$prefer"
        return 0
    fi
    set +e
    tags="$(curl -fsSL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases?per_page=30" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')"
    set -e
    for tag in $tags; do
        if release_asset_exists "$tag" "$target"; then
            printf '%s\n' "$tag"
            return 0
        fi
    done
    return 1
}

resolve_download_version() {
    local version target baked
    version=""
    baked=""
    target="$(download_target)" || exit 1
    if [ -n "${ZNVM_VERSION_ARG:-}" ]; then
        version="$ZNVM_VERSION_ARG"
    elif [ "$ZNVM_VERSION" != "main" ]; then
        version="$ZNVM_VERSION"
        baked="$ZNVM_VERSION"
    else
        set +e
        version=$(curl -fsSL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
        set -e
    fi
    if [ -z "$version" ]; then
        echo "error: Could not determine which nvm version to download." >&2
        exit 1
    fi
    if ! release_asset_exists "$version" "$target"; then
        if [ -n "${ZNVM_VERSION_ARG:-}" ]; then
            echo "error: No published nvm binary for ${target} (${version})." >&2
            exit 1
        fi
        version="$(find_published_version "$target" "")" || {
            echo "error: No published nvm binary for ${target}." >&2
            exit 1
        }
        if [ -n "$baked" ] && [ "$version" != "$baked" ]; then
            install_msg version_fallback "$version" "$baked"
        fi
    fi
    printf '%s\n' "$version"
}

download_target() {
    local os arch target
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
    printf '%s\n' "$target"
}

fetch_binary() {
    local dest="$1"
    local version="$2"
    local target url
    target="$(download_target)" || exit 1
    url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$version/znvm-$version-$target"
    install_msg downloading "$version" "$target"
    if ! curl -fL --retry 3 -o "$dest" "$url"; then
        rm -f "$dest"
        install_msg download_failed "$url"
        exit 1
    fi
    chmod +x "$dest"
}

backup_and_replace() {
    local dest="$1"
    local staged="$2"
    local old_ver="$3"
    local new_ver="$4"
    local backup
    backup="${dest}.bak"

    if [ -d "$dest" ]; then
        rm -f "$staged"
        echo "Refusing to replace directory $dest" >&2
        exit 1
    fi

    if [ ! -e "$backup" ]; then
        if [ -L "$dest" ]; then
            cp -pL "$dest" "$backup" 2>/dev/null || cp -p "$dest" "$backup"
        else
            cp -p "$dest" "$backup"
        fi
        install_msg saved_backup "$dest" "$backup"
    fi
    mv -f "$staged" "$dest"
    chmod +x "$dest"
    if [ -z "$old_ver" ]; then
        old_ver="unknown"
    fi
    install_msg upgraded "$old_ver" "$new_ver"
}

install_binary() {
    local dest_dir dest old_ver new_ver staged

    if [ -n "${ZNVM_BIN_SRC:-}" ]; then
        if [ ! -f "$ZNVM_BIN_SRC" ]; then
            echo "Install source does not exist: $ZNVM_BIN_SRC" >&2
            exit 1
        fi
        dest_dir="${ZNVM_INSTALL_BIN_DIR:-$NVM_COMPAT_DIR}"
        mkdir -p "$dest_dir"
        dest="$dest_dir/nvm"
        new_ver="$(installed_version "$ZNVM_BIN_SRC")" || exit 1
        if [ -x "$dest" ] && [ ! -d "$dest" ]; then
            old_ver="$(installed_version "$dest")"
            if [ -n "$new_ver" ] && [ "$old_ver" = "$new_ver" ]; then
                printf '%s\n' "$dest"
                return
            fi
            staged="$(mktemp "$dest_dir/.nvm-new.XXXXXX")" || exit 1
            cp "$ZNVM_BIN_SRC" "$staged"
            chmod +x "$staged"
            backup_and_replace "$dest" "$staged" "$old_ver" "$new_ver"
            printf '%s\n' "$dest"
            return
        fi
        cp "$ZNVM_BIN_SRC" "$dest"
        chmod +x "$dest"
        printf '%s\n' "$dest"
        return
    fi

    dest_dir="$(choose_bin_dir)"
    mkdir -p "$dest_dir"
    dest="$dest_dir/nvm"
    new_ver="$(resolve_download_version)" || exit 1
    if [ -x "$dest" ] && [ ! -d "$dest" ]; then
        old_ver="$(installed_version "$dest")"
        if [ "$old_ver" = "$new_ver" ]; then
            printf '%s\n' "$dest"
            return
        fi
        staged="$(mktemp "$dest_dir/.nvm-new.XXXXXX")" || exit 1
        fetch_binary "$staged" "$new_ver"
        backup_and_replace "$dest" "$staged" "$old_ver" "$new_ver"
        printf '%s\n' "$dest"
        return
    fi
    fetch_binary "$dest" "$new_ver"
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
__nvm_path=":${PATH:-}:"
__nvm_path="${__nvm_path//:$__nvm_bin_dir:/:}"
__nvm_path="${__nvm_path#:}"
__nvm_path="${__nvm_path%:}"
if [ -n "$__nvm_path" ]; then
    PATH="$__nvm_bin_dir:$__nvm_path"
else
    PATH="$__nvm_bin_dir"
fi
export PATH
unset __nvm_path
eval "$("$NVM_BIN" env)"
EOF
    } | safe_replace "$NVM_COMPAT_DIR/nvm.sh" "$NVM_COMPAT_DIR/nvm.sh.bak"
    install_msg wrote_nvm_sh "$NVM_COMPAT_DIR/nvm.sh"
}

configure_profile() {
    local profile
    profile="$(profile_path)"

    if [ -d "$profile" ]; then
        echo "Refusing to write shell config into directory $profile" >&2
        exit 1
    fi

    if [ -f "$profile" ] && grep -q 'NVM_DIR/nvm.sh' "$profile"; then
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
    install_msg added_profile "$profile"
    printf '%s\n' "$profile"
}

link_nrm() {
    local exe="$1"
    local dir base link target
    dir="$(dirname "$exe")"
    base="$(basename "$exe")"
    link="$dir/nrm"

    if [ -L "$link" ]; then
        target="$(readlink "$link")"
        if [ "$target" = "$base" ] || [ "$target" = "$exe" ]; then
            :
        else
            install_msg nrm_link_blocked "$link"
        fi
    elif [ -e "$link" ]; then
        install_msg nrm_link_blocked "$link"
    else
        ln -s "$base" "$link"
    fi
    note_other_nrm "$link"
}

note_other_nrm() {
    local ours="$1"
    local dir cand target
    local IFS=':'
    for dir in ${PATH:-}; do
        [ -n "$dir" ] || continue
        cand="$dir/nrm"
        if [ ! -e "$cand" ] && [ ! -L "$cand" ]; then
            continue
        fi
        if [ "$cand" = "$ours" ]; then
            continue
        fi
        install_msg nrm_other "$cand"
        if [ -L "$ours" ]; then
            target="$(readlink "$ours")"
            if [ "$target" = "nvm" ] || [ "$target" = "$(dirname "$ours")/nvm" ]; then
                install_msg nrm_path_hint "$ours"
            fi
        fi
        return
    done
}

remove_nrm_link() {
    local exe="$1"
    local link target base
    link="$(dirname "$exe")/nrm"
    base="$(basename "$exe")"
    if [ -L "$link" ]; then
        target="$(readlink "$link")"
        if [ "$target" = "$base" ] || [ "$target" = "$exe" ]; then
            rm -f "$link"
            echo "ok Removed $link"
        else
            echo "note: $link does not point at $base and was left in place."
        fi
    elif [ -e "$link" ]; then
        echo "note: $link is not the nvm link and was left in place."
    fi
}

profile_path() {
    local shell_name
    if [ -n "${ZNVM_PROFILE:-}" ]; then
        printf '%s\n' "$ZNVM_PROFILE"
        return
    fi
    shell_name="$(basename "${SHELL:-bash}")"
    case "$shell_name" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                printf '%s\n' "$HOME/.bashrc"
            else
                printf '%s\n' "$HOME/.bash_profile"
            fi
            ;;
        zsh)
            printf '%s\n' "$HOME/.zshrc"
            ;;
        *)
            printf '%s\n' "$HOME/.profile"
            ;;
    esac
}

remove_shell_block() {
    local profile="$1"
    local tmp
    [ -f "$profile" ] || return 0
    if ! grep -q "$MARKER" "$profile"; then
        return 0
    fi
    tmp="$(mktemp)"
    awk -v marker="$MARKER" '
        index($0, marker) { skipping = 1; next }
        skipping && index($0, "NVM_DIR/nvm.sh") { skipping = 0; next }
        skipping { next }
        { print }
    ' "$profile" > "$tmp"
    mv "$tmp" "$profile"
    echo "ok Removed nvm startup from $profile"
}

resolve_nvm_path() {
    local dir
    if [ -n "${ZNVM_BIN_SRC:-}" ]; then
        printf '%s\n' "${ZNVM_INSTALL_BIN_DIR:-$NVM_COMPAT_DIR}/nvm"
        return
    fi
    if [ -n "${ZNVM_INSTALL_BIN_DIR:-}" ]; then
        printf '%s\n' "$ZNVM_INSTALL_BIN_DIR/nvm"
        return
    fi
    dir="$(choose_bin_dir)"
    if [ -x "$dir/nvm" ]; then
        printf '%s\n' "$dir/nvm"
        return
    fi
    if [ -x "$NVM_COMPAT_DIR/nvm" ]; then
        printf '%s\n' "$NVM_COMPAT_DIR/nvm"
        return
    fi
    printf '%s\n' "$dir/nvm"
}

uninstall_nvm() {
    local dest profile
    dest="$(resolve_nvm_path)"
    remove_nrm_link "$dest"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -f "$dest"
        echo "ok Removed $dest"
    fi
    if [ -f "$NVM_COMPAT_DIR/nvm.sh" ] && grep -q "$MARKER" "$NVM_COMPAT_DIR/nvm.sh"; then
        if [ -f "$NVM_COMPAT_DIR/nvm.sh.bak" ]; then
            mv "$NVM_COMPAT_DIR/nvm.sh.bak" "$NVM_COMPAT_DIR/nvm.sh"
            echo "ok Restored $NVM_COMPAT_DIR/nvm.sh"
        else
            rm -f "$NVM_COMPAT_DIR/nvm.sh"
            echo "ok Removed $NVM_COMPAT_DIR/nvm.sh"
        fi
    fi
    profile="$(profile_path)"
    remove_shell_block "$profile"
    echo "ok Uninstalled nvm. Node versions in $NVM_COMPAT_DIR were kept."
}

if [ "${1:-}" = "--uninstall" ]; then
    uninstall_nvm
    exit 0
fi

ZNVM_VERSION_ARG="${1:-}"
NVM_EXE="$(install_binary)"
INSTALL_MSG_LANG=""
link_nrm "$NVM_EXE"
if [ ! -x "$NVM_EXE" ]; then
    echo "nvm was not installed." >&2
    exit 1
fi

write_nvm_sh "$NVM_EXE"
PROFILE_PATH="$(configure_profile)"
INSTALL_LANG="$(NVM_DIR="$NVM_COMPAT_DIR" "$NVM_EXE" lang)"
NVM_DIR="$NVM_COMPAT_DIR" "$NVM_EXE" mirror preset
PROFILE_SHORT="$(profile_display "$PROFILE_PATH")"
if [ "$INSTALL_LANG" = zh ]; then
    echo "完成"
else
    echo "Done."
fi
echo "  source $PROFILE_SHORT"
