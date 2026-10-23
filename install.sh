#!/bin/bash

set -e

# Header
if [ "${1:-}" != "--uninstall" ]; then
    echo "znvm: Zig Node Version Manager"
    echo "Node.js version manager. nvm-compatible layout."
    echo ""
fi

# Version baked in at release time. Update this line when publishing.
ZNVM_VERSION="v2.9.0"

ZNVM_DIR="$HOME/.znvm"
REPO_URL="https://github.com/charlzyx/znvm.git"
REPO_OWNER="charlzyx"
REPO_NAME="znvm"

INSTALL_BIN_DIR="$ZNVM_DIR/bin"
ADD_TO_PATH=true

# Parse PATH into array (handles spaces in paths correctly)
# Split PATH by ':'
IFS=':' read -ra PATH_DIRS <<< "$PATH"

# Iterate through PATH directories to find a suitable install location
# We prioritize user-specific directories
for dir in "${PATH_DIRS[@]}"; do
    # Skip if directory doesn't exist or isn't writable
    if [ ! -d "$dir" ] || [ ! -w "$dir" ]; then
        continue
    fi
    
    # Check if it's a allowed user bin directory
    case "$dir" in
        "$HOME/bin"|"$HOME/.local/bin"|"$HOME/.bin"|"/usr/local/bin")
            INSTALL_BIN_DIR="$dir"
            ADD_TO_PATH=false
            break
            ;;
    esac
done

link_nrm() {
    local exe="$1"
    local dir base link target other
    dir="$(dirname "$exe")"
    base="$(basename "$exe")"
    link="$dir/nrm"

    if [ -L "$link" ]; then
        target="$(readlink "$link")"
        if [ "$target" = "$base" ] || [ "$target" = "$exe" ]; then
            echo "ok nrm 已链接 $link"
            echo "ok nrm already linked at $link"
        else
            echo "note: $link 已存在, 未改动."
            echo "note: $link already exists and was not changed."
            echo "note: 未在 $base 旁链接 nrm. 移走该文件后重新安装."
            echo "note: nrm was not linked next to $base. Move that file and run the installer again."
        fi
    elif [ -e "$link" ]; then
        echo "note: $link 已存在, 未改动."
        echo "note: $link already exists and was not changed."
        echo "note: 未在 $base 旁链接 nrm. 移走该文件后重新安装."
        echo "note: nrm was not linked next to $base. Move that file and run the installer again."
    else
        ln -s "$base" "$link"
        echo "ok 已链接 $link -> $base"
        echo "ok Linked $link -> $base"
    fi

    local IFS=':'
    for other in ${PATH:-}; do
        [ -n "$other" ] || continue
        if [ ! -e "$other/nrm" ] && [ ! -L "$other/nrm" ]; then
            continue
        fi
        if [ "$other/nrm" = "$link" ]; then
            continue
        fi
        echo "note: 未删除 PATH 上的另一个 nrm: $other/nrm"
        echo "note: another nrm is at $other/nrm and was not removed."
        if [ -L "$link" ]; then
            target="$(readlink "$link")"
            if [ "$target" = "$base" ] || [ "$target" = "$exe" ]; then
                if [ "$ADD_TO_PATH" = true ]; then
                    echo "note: shell 配置会把 $(dirname "$link") 放在 PATH 前面, 因此 $link 作为 nrm 运行."
                    echo "note: the shell profile puts $(dirname "$link") first on PATH, so $link runs as nrm."
                else
                    echo "note: $link 在 znvm 旁边. 若另一个 nrm 在 PATH 中更靠前, 运行的仍是那一个."
                    echo "note: $link is beside znvm. If another nrm is earlier on PATH, that one still runs."
                fi
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
            echo "ok 已删除 $link"
            echo "ok Removed $link"
        else
            echo "note: $link 不是指向 $base 的链接, 已保留."
            echo "note: $link does not point at $base and was left in place."
        fi
    elif [ -e "$link" ]; then
        echo "note: $link 不是本次安装的链接, 已保留."
        echo "note: $link is not this install and was left in place."
    fi
}

uninstall_znvm() {
    local exe profile tmp
    exe="$INSTALL_BIN_DIR/znvm"
    remove_nrm_link "$exe"
    if [ -e "$exe" ] || [ -L "$exe" ]; then
        rm -f "$exe"
        echo "ok 已删除 $exe"
        echo "ok Removed $exe"
    fi

    SHELL_NAME=$(basename "${SHELL:-bash}")
    case "$SHELL_NAME" in
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
    if [ -f "$profile" ] && grep -q "znvm env" "$profile"; then
        tmp="$(mktemp)"
        awk '
            $0 == "# znvm" { skipping = 1; next }
            skipping && $0 ~ /znvm env/ { skipping = 0; next }
            skipping && ($0 ~ /^export PATH=/ || $0 == "") { next }
            skipping { skipping = 0 }
            { print }
        ' "$profile" > "$tmp"
        mv "$tmp" "$profile"
        echo "ok 已从 $profile 移除 znvm 启动行"
        echo "ok Removed znvm startup from $profile"
    fi
    echo "ok 已卸载. Node 版本目录未删除."
    echo "ok Uninstalled. Node version directories were kept."
}

if [ "${1:-}" = "--uninstall" ]; then
    uninstall_znvm
    exit 0
fi

VERSION_ARG="$1"

# 确定要使用的版本
# Priority: argument, then the baked-in version, then the latest release.
if [ -n "$VERSION_ARG" ]; then
    VERSION="$VERSION_ARG"
elif [ "$ZNVM_VERSION" != "main" ]; then
    VERSION="$ZNVM_VERSION"
    echo "> 使用内置版本: $VERSION"
    echo "> Using built-in version: $VERSION"
else
    VERSION=""
fi

echo "> 安装 znvm 到 $ZNVM_DIR"
echo "> Installing znvm to $ZNVM_DIR"
echo "> Binary will be installed to $INSTALL_BIN_DIR"

# 确保目录存在
mkdir -p "$ZNVM_DIR"
mkdir -p "$INSTALL_BIN_DIR"

# 检测平台和架构
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
TARGET=""

if [ "$OS" = "darwin" ]; then
    if [ "$ARCH" = "arm64" ]; then
        TARGET="aarch64-macos"
    else
        TARGET="x86_64-macos"
    fi
elif [ "$OS" = "linux" ]; then
    if [ "$ARCH" = "aarch64" ]; then
        TARGET="aarch64-linux-musl"
    elif [ "$ARCH" = "x86_64" ]; then
        TARGET="x86_64-linux-musl"
    fi
fi

# 标记是否成功下载预编译版本
BINARY_DOWNLOADED=false

installed_version() {
    local exe="$1"
    local out
    out=""
    if [ -x "$exe" ] && [ ! -d "$exe" ]; then
        set +e
        out=$("$exe" --version 2>/dev/null | head -n 1)
        set -e
    fi
    printf '%s\n' "$out" | tr -d '\r'
}

# Download beside the live binary, then replace it. A failed download removes
# only the temporary file.
stage_binary() {
    local dest="$1"
    local url="$2"
    local old_ver="$3"
    local new_ver="$4"
    local staged backup
    staged=$(mktemp "$INSTALL_BIN_DIR/.znvm-new.XXXXXX") || return 1
    if curl -L -o "$staged" "$url" --fail 2>/dev/null; then
        chmod +x "$staged"
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ -d "$dest" ]; then
                rm -f "$staged"
                echo "error: 拒绝替换目录 $dest"
                echo "error: Refusing to replace directory $dest"
                return 1
            fi
            backup="${dest}.bak"
            if [ ! -e "$backup" ]; then
                if [ -L "$dest" ]; then
                    cp -pL "$dest" "$backup" 2>/dev/null || cp -p "$dest" "$backup"
                else
                    cp -p "$dest" "$backup"
                fi
                echo "> 已保存之前的 $dest 为 $backup"
                echo "> Saved the previous $dest as $backup"
            else
                echo "ok 之前的副本已在 $backup"
                echo "ok Previous copy already exists at $backup"
            fi
            mv -f "$staged" "$dest"
            chmod +x "$dest"
            if [ -z "$old_ver" ]; then
                old_ver="unknown"
            fi
            echo "ok 已升级 znvm $old_ver -> $new_ver"
            echo "ok Upgraded znvm $old_ver -> $new_ver"
        else
            mv -f "$staged" "$dest"
            chmod +x "$dest"
            echo "ok 二进制文件下载成功"
            echo "ok Binary downloaded"
        fi
        return 0
    fi
    rm -f "$staged"
    echo "error: 预编译二进制文件下载失败"
    echo "error: Failed to download pre-compiled binary."
    return 1
}

# 1. 尝试下载预编译二进制文件
if [ -n "$TARGET" ]; then
    # 确定要下载的版本
    if [ -n "$VERSION" ]; then
        echo "> 使用指定版本: $VERSION"
        echo "> Using specified version: $VERSION"
    else
        echo "> 获取最新版本信息"
        echo "> Fetching latest version info"

        # 从 GitHub API 获取最新 release tag
        set +e
        VERSION=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
        set -e

        if [ -n "$VERSION" ]; then
            echo "> 最新版本: $VERSION"
            echo "> Latest version: $VERSION"
        fi
    fi

    if [ -n "$VERSION" ]; then
        DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/znvm-$VERSION-$TARGET"
        DEST="$INSTALL_BIN_DIR/znvm"
        OLD_VER=""
        if [ -x "$DEST" ] && [ ! -d "$DEST" ]; then
            OLD_VER=$(installed_version "$DEST")
        fi

        if [ -n "$OLD_VER" ] && [ "$OLD_VER" = "$VERSION" ]; then
            link_nrm "$DEST"
            BINARY_DOWNLOADED=true
            echo "ok znvm 已安装 $DEST"
            echo "ok znvm is already installed at $DEST"
        else
            echo "> 尝试下载预编译二进制文件 ($TARGET)"
            echo "> Attempting to download pre-compiled binary ($TARGET)"
            if stage_binary "$DEST" "$DOWNLOAD_URL" "$OLD_VER" "$VERSION"; then
                link_nrm "$DEST"
                BINARY_DOWNLOADED=true
            fi
        fi
    else
        echo "error: 无法获取版本信息"
        echo "error: Failed to get version info."
    fi
else
    echo "error: 未找到当前平台的预编译版本"
    echo "error: No pre-compiled binary found for current platform."
fi

# 2. If the download failed, print an error and exit.
if [ "$BINARY_DOWNLOADED" = false ]; then
    echo ""
    echo "error: 安装失败"
    echo "error: Installation failed"
    echo ""
    echo "原因: 当前平台 (${OS}/${ARCH}) 暂无可用的预编译二进制文件."
    echo "Reason: No pre-compiled binary available for current platform (${OS}/${ARCH})."
    echo ""
    echo "您可以尝试以下解决方案:"
    echo "You can try the following solutions:"
    echo ""
    echo "1. 手动编译安装"
    echo "1. Compile manually:"
    echo "   git clone $REPO_URL $ZNVM_DIR"
    echo "   cd $ZNVM_DIR"
    echo "   zig build -Doptimize=ReleaseFast"
    echo "   cp zig-out/bin/znvm $INSTALL_BIN_DIR/znvm"
    echo ""
    echo "2. 或者等待官方支持"
    echo "2. Or wait for official support:"
    echo "   在 GitHub 提交 issue 请求支持 ${OS}/${ARCH} 平台"
    echo "   Submit an issue on GitHub to request ${OS}/${ARCH} support"
    echo ""
    exit 1
fi

# 3. 配置 Shell 环境
SHELL_NAME=$(basename "$SHELL")
PROFILE=""

case "$SHELL_NAME" in
    bash)
        if [ -f "$HOME/.bashrc" ]; then
            PROFILE="$HOME/.bashrc"
        else
            PROFILE="$HOME/.bash_profile"
        fi
        ;;
    zsh)
        PROFILE="$HOME/.zshrc"
        ;;
    *)
        PROFILE="$HOME/.profile"
        ;;
esac

if [ "$ADD_TO_PATH" = true ]; then
    CLEAN_INSTALL_DIR="${INSTALL_BIN_DIR/#$HOME/\$HOME}"
    SOURCE_STR="export PATH=\"$CLEAN_INSTALL_DIR:\$PATH\"
eval \"\$(znvm env)\""
else
    SOURCE_STR="eval \"\$(znvm env)\""
fi

if [ -f "$PROFILE" ] && grep -q "znvm env" "$PROFILE"; then
    echo "ok znvm 已在 $PROFILE 中配置"
    echo "ok znvm is already configured in $PROFILE"
else
    echo "> 添加配置到 $PROFILE"
    echo "> Adding configuration to $PROFILE"
    echo "" >> "$PROFILE"
    echo "# znvm" >> "$PROFILE"
    echo "$SOURCE_STR" >> "$PROFILE"
fi

if [ "$BINARY_DOWNLOADED" = true ]; then
    ZNVM_EXE="$INSTALL_BIN_DIR/znvm"
    if [ -x "$ZNVM_EXE" ]; then
        "$ZNVM_EXE" mirror preset
    fi
fi

echo ""
echo "ok 安装完成"
echo "ok Installation complete."
echo "请重新打开终端或运行:"
echo "Open a new terminal, or run:"
echo "  source $PROFILE"
echo ""
