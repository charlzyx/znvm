#!/bin/bash

set -e

# Header
echo "znvm: Zig Node Version Manager"
echo "Node.js version manager. nvm-compatible layout, npmmirror by default."
echo ""

# Version baked in at release time. Update this line when publishing.
ZNVM_VERSION="v2.4.0"

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
        VERSION=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)

        if [ -n "$VERSION" ]; then
            echo "> 最新版本: $VERSION"
            echo "> Latest version: $VERSION"
        fi
    fi

    if [ -n "$VERSION" ]; then
        DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/znvm-$VERSION-$TARGET"

        echo "> 尝试下载预编译二进制文件 ($TARGET)"
        echo "> Attempting to download pre-compiled binary ($TARGET)"

        if curl -L -o "$INSTALL_BIN_DIR/znvm" "$DOWNLOAD_URL" --fail 2>/dev/null; then
            chmod +x "$INSTALL_BIN_DIR/znvm"
            BINARY_DOWNLOADED=true
            echo "ok 二进制文件下载成功"
            echo "ok Binary downloaded"
        else
            echo "error: 预编译二进制文件下载失败"
            echo "error: Failed to download pre-compiled binary."
            rm -f "$INSTALL_BIN_DIR/znvm"
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

echo ""
echo "ok 安装完成"
echo "ok Installation complete."
echo "请重新打开终端或运行:"
echo "Open a new terminal, or run:"
echo "  source $PROFILE"
echo ""
