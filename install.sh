#!/bin/bash

set -e

# 版本号（发布时更新此行）
ZNVM_VERSION="main"

ZNVM_DIR="$HOME/.znvm"
REPO_URL="https://github.com/charlzyx/znvm.git"
REPO_OWNER="charlzyx"
REPO_NAME="znvm"

VERSION_ARG="$1"

# 优先级：参数 > 当前版本 > 最新
if [ -n "$VERSION_ARG" ]; then
    VERSION="$VERSION_ARG"
elif [ "$ZNVM_VERSION" != "main" ]; then
    VERSION="$ZNVM_VERSION"
    echo "=> 使用内置版本 / Using built-in version: $VERSION"
else
    VERSION=""
fi

# 尝试从 URL 中提取版本号
if [ -n "$SCRIPT_URL" ]; then
    VERSION_FROM_URL=$(echo "$SCRIPT_URL" | sed -n 's|.*/\(v[0-9.]*\)/install.sh|\1|p')
    if [ -n "$VERSION_FROM_URL" ]; then
        echo "=> 从 URL 检测到版本: $VERSION_FROM_URL"
        echo "=> Detected version from URL: $VERSION_FROM_URL"
    fi
fi

# 优先级：URL > 参数 > 最新
if [ -n "$VERSION_FROM_URL" ]; then
    VERSION="$VERSION_FROM_URL"
elif [ -n "$VERSION_ARG" ]; then
    VERSION="$VERSION_ARG"
else
    VERSION=""
fi

echo "=> 安装 znvm 到 $ZNVM_DIR..."
echo "=> Installing znvm to $ZNVM_DIR..."

# 确保目录存在
mkdir -p "$ZNVM_DIR/bin"

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
    # 确定要下载的版本（VERSION 已在脚本开头设置：URL > 参数 > 空）
    if [ -n "$VERSION" ]; then
        echo "=> 使用指定版本 / Using specified version: $VERSION"
    else
        echo "=> 获取最新版本信息..."
        echo "=> Fetching latest version info..."

        # 从 GitHub API 获取最新 release tag
        VERSION=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)

        if [ -n "$VERSION" ]; then
            echo "=> 最新版本 / Latest version: $VERSION"
        fi
    fi
    
    if [ -n "$VERSION" ]; then
        DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/znvm-core-$VERSION-$TARGET"
        
        echo "=> 尝试下载预编译二进制文件 ($TARGET)..."
        echo "=> Attempting to download pre-compiled binary ($TARGET)..."
        
        if curl -L -o "$ZNVM_DIR/bin/znvm-core" "$DOWNLOAD_URL" --fail 2>/dev/null; then
            chmod +x "$ZNVM_DIR/bin/znvm-core"
            BINARY_DOWNLOADED=true
            echo "=> 二进制文件下载成功！"
            echo "=> Binary downloaded successfully!"

            # 同时下载对应版本的 znvm.sh
            ZNVM_SH_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$VERSION/znvm.sh"
            echo "=> 下载 znvm.sh..."
            echo "=> Downloading znvm.sh..."
            if curl -L -o "$ZNVM_DIR/znvm.sh" "$ZNVM_SH_URL" --fail 2>/dev/null; then
                chmod +x "$ZNVM_DIR/znvm.sh"
                echo "=> znvm.sh 下载成功！"
                echo "=> znvm.sh downloaded successfully!"
            else
                echo "=> 警告: znvm.sh 下载失败，将在首次运行时尝试从仓库获取。"
                echo "=> Warning: Failed to download znvm.sh, will attempt to fetch from repository on first run."
            fi
        else
            echo "=> 预编译二进制文件下载失败。"
            echo "=> Failed to download pre-compiled binary."
            rm -f "$ZNVM_DIR/bin/znvm-core"
        fi
            
    
    else
        echo "=> 无法获取版本信息。"
        echo "=> Failed to get version info."
    fi
else
    echo "=> 未找到当前平台的预编译版本。"
    echo "=> No pre-compiled binary found for current platform."
fi

# 2. 如果下载失败，则克隆仓库（后续 znvm.sh 会在首次运行时编译）
if [ "$BINARY_DOWNLOADED" = false ]; then
    echo ""
    echo "=> 将克隆源码仓库（首次运行时将自动编译）..."
    echo "=> Will clone source repository (will auto-compile on first run)..."
    
    if [ -d "$ZNVM_DIR/.git" ]; then
        echo "=> 更新 znvm..."
        echo "=> Updating znvm..."
        cd "$ZNVM_DIR" && git pull origin main
    else
        echo "=> 克隆 znvm..."
        echo "=> Cloning znvm..."
        git clone "$REPO_URL" "$ZNVM_DIR"
    fi
    
    echo ""
    echo "=> 提示: 未找到预编译二进制文件，首次运行 'nv' 时将尝试自动编译 (需安装 Zig)。"
    echo "=> Note: No pre-compiled binary found, will attempt to compile automatically on first run of 'nv' (requires Zig)."
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
