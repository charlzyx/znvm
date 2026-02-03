#!/bin/bash

set -e

ZNVM_DIR="$HOME/.znvm"
REPO_URL="https://github.com/charlzyx/znvm.git" # 请替换为实际仓库地址

echo "=> 安装 znvm 到 $ZNVM_DIR..."
echo "=> Installing znvm to $ZNVM_DIR..."

# 1. 克隆或更新仓库
if [ -d "$ZNVM_DIR/.git" ]; then
    echo "=> 更新 znvm..."
    echo "=> Updating znvm..."
    cd "$ZNVM_DIR" && git pull origin main
else
    echo "=> 克隆 znvm..."
    echo "=> Cloning znvm..."
    git clone "$REPO_URL" "$ZNVM_DIR"
fi

# 2. 尝试下载预编译二进制文件
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
BIN_NAME="znvm-core"
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

if [ -n "$TARGET" ]; then
    # 获取最新 release 版本 (简化版：假设是 v0.1.0，实际应从 GitHub API 获取)
    # 这里我们尝试从仓库的 release 页面下载
    # 注意：需要替换为真实的仓库所有者和项目名
    # 假设 tag 是 v0.1.0
    VERSION="v0.1.0" 
    DOWNLOAD_URL="https://github.com/charlzyx/znvm/releases/download/$VERSION/znvm-core-$TARGET"
    
    echo "=> 尝试下载预编译二进制文件 ($TARGET)..."
    echo "=> Attempting to download pre-compiled binary ($TARGET)..."
    mkdir -p "$ZNVM_DIR/bin"
    
    if curl -L -o "$ZNVM_DIR/bin/znvm-core" "$DOWNLOAD_URL" --fail; then
        chmod +x "$ZNVM_DIR/bin/znvm-core"
        echo "=> 二进制文件安装成功！"
        echo "=> Binary installed successfully!"
    else
        echo "=> 下载失败 (可能尚未发布 release)，将在首次运行时尝试本地编译。"
        echo "=> Download failed (release might not exist yet), will fallback to local compilation on first run."
        rm -f "$ZNVM_DIR/bin/znvm-core"
    fi
else
    echo "=> 未找到当前平台的预编译版本，将在首次运行时尝试本地编译。"
    echo "=> No pre-compiled binary found for current platform, will fallback to local compilation on first run."
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

SOURCE_STR="export ZNVM_ROOT=\"$ZNVM_DIR\" && source \"\$ZNVM_ROOT/znvm.sh\""

if [ -f "$PROFILE" ] && grep -q "znvm.sh" "$PROFILE"; then
    echo "=> znvm 已在 $PROFILE 中配置。"
    echo "=> znvm is already configured in $PROFILE."
else
    echo "=> 添加配置到 $PROFILE..."
    echo "=> Adding configuration to $PROFILE..."
    echo "" >> "$PROFILE"
    echo "# znvm configuration" >> "$PROFILE"
    echo "$SOURCE_STR" >> "$PROFILE"
fi

echo ""
echo "=> 安装成功！"
echo "=> Installation successful!"
echo "=> 请重新打开终端或运行以下命令生效："
echo "=> Please restart your terminal or run the following command to take effect:"
echo "   source $PROFILE"
echo ""
echo "=> 首次运行 'nv' 命令时，如果未找到预编译二进制，将尝试自动编译 (需安装 Zig)。"
echo "=> On first run of 'nv', if no pre-compiled binary is found, it will attempt to compile automatically (requires Zig)."
