#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Header
echo -e "${CYAN}${BOLD}znvm: Zig Node Version Manager${NC}"
echo -e "${BLUE}The blazingly fast, zero-config Node.js version manager.${NC}"
echo ""

# 版本号（发布时更新此行）
ZNVM_VERSION="v1.1.3"

ZNVM_DIR="$HOME/.znvm"
REPO_URL="https://github.com/charlzyx/znvm.git"
REPO_OWNER="charlzyx"
REPO_NAME="znvm"

VERSION_ARG="$1"

# 确定要使用的版本
# 优先级：参数 > 内置版本 > 获取最新
if [ -n "$VERSION_ARG" ]; then
    VERSION="$VERSION_ARG"
elif [ "$ZNVM_VERSION" != "main" ]; then
    VERSION="$ZNVM_VERSION"
    echo -e "${GREEN}=> 使用内置版本 / Using built-in version: ${BOLD}$VERSION${NC}"
else
    VERSION=""
fi

echo -e "${CYAN}=> 安装 znvm 到 $ZNVM_DIR...${NC}"
echo -e "${CYAN}=> Installing znvm to $ZNVM_DIR...${NC}"

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
    # 确定要下载的版本
    if [ -n "$VERSION" ]; then
        echo -e "${GREEN}=> 使用指定版本 / Using specified version: ${BOLD}$VERSION${NC}"
    else
        echo -e "${YELLOW}=> 获取最新版本信息...${NC}"
        echo -e "${YELLOW}=> Fetching latest version info...${NC}"

        # 从 GitHub API 获取最新 release tag
        VERSION=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)

        if [ -n "$VERSION" ]; then
            echo -e "${GREEN}=> 最新版本 / Latest version: ${BOLD}$VERSION${NC}"
        fi
    fi

    if [ -n "$VERSION" ]; then
        DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/znvm-core-$VERSION-$TARGET"

        echo -e "${CYAN}=> 尝试下载预编译二进制文件 ($TARGET)...${NC}"
        echo -e "${CYAN}=> Attempting to download pre-compiled binary ($TARGET)...${NC}"

        if curl -L -o "$ZNVM_DIR/bin/znvm-core" "$DOWNLOAD_URL" --fail 2>/dev/null; then
            chmod +x "$ZNVM_DIR/bin/znvm-core"
            BINARY_DOWNLOADED=true
            echo -e "${GREEN}✔ 二进制文件下载成功！${NC}"
            echo -e "${GREEN}✔ Binary downloaded successfully!${NC}"

            # 同时下载对应版本的 znvm.sh
            ZNVM_SH_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$VERSION/znvm.sh"
            echo -e "${CYAN}=> 下载 znvm.sh...${NC}"
            echo -e "${CYAN}=> Downloading znvm.sh...${NC}"
            if curl -L -o "$ZNVM_DIR/znvm.sh" "$ZNVM_SH_URL" --fail 2>/dev/null; then
                chmod +x "$ZNVM_DIR/znvm.sh"
                echo -e "${GREEN}✔ znvm.sh 下载成功！${NC}"
                echo -e "${GREEN}✔ znvm.sh downloaded successfully!${NC}"
            else
                echo -e "${YELLOW}⚠ 警告: znvm.sh 下载失败，将在首次运行时尝试从仓库获取。${NC}"
                echo -e "${YELLOW}⚠ Warning: Failed to download znvm.sh, will attempt to fetch from repository on first run.${NC}"
            fi
        else
            echo -e "${RED}✘ 预编译二进制文件下载失败。${NC}"
            echo -e "${RED}✘ Failed to download pre-compiled binary.${NC}"
            rm -f "$ZNVM_DIR/bin/znvm-core"
        fi
    else
        echo -e "${RED}✘ 无法获取版本信息。${NC}"
        echo -e "${RED}✘ Failed to get version info.${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 未找到当前平台的预编译版本。${NC}"
    echo -e "${YELLOW}⚠ No pre-compiled binary found for current platform.${NC}"
fi

# 2. 如果下载失败，则克隆仓库（后续 znvm.sh 会在首次运行时编译）
if [ "$BINARY_DOWNLOADED" = false ]; then
    echo ""
    echo -e "${CYAN}=> 将克隆源码仓库（首次运行时将自动编译）...${NC}"
    echo -e "${CYAN}=> Will clone source repository (will auto-compile on first run)...${NC}"

    if [ -d "$ZNVM_DIR/.git" ]; then
        echo -e "${CYAN}=> 更新 znvm...${NC}"
        echo -e "${CYAN}=> Updating znvm...${NC}"
        cd "$ZNVM_DIR" && git pull origin main
    else
        echo -e "${CYAN}=> 克隆 znvm...${NC}"
        echo -e "${CYAN}=> Cloning znvm...${NC}"
        git clone "$REPO_URL" "$ZNVM_DIR"
    fi

    echo ""
    echo -e "${YELLOW}⚡ 提示: 未找到预编译二进制文件，首次运行 'nv' 时将尝试自动编译 (需安装 Zig)。${NC}"
    echo -e "${YELLOW}⚡ Note: No pre-compiled binary found, will attempt to compile automatically on first run of 'nv' (requires Zig).${NC}"
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
    echo -e "${GREEN}✔ znvm 已在 $PROFILE 中配置。${NC}"
    echo -e "${GREEN}✔ znvm is already configured in $PROFILE.${NC}"
else
    echo -e "${CYAN}=> 添加配置到 $PROFILE...${NC}"
    echo -e "${CYAN}=> Adding configuration to $PROFILE...${NC}"
    echo "" >> "$PROFILE"
    echo "# znvm configuration" >> "$PROFILE"
    echo "$SOURCE_STR" >> "$PROFILE"
fi

echo ""
echo -e "${GREEN}${BOLD}🎉 安装成功！${NC}"
echo -e "${GREEN}${BOLD}🎉 Installation successful!${NC}"
echo -e "${CYAN}请重新打开终端或运行以下命令生效：${NC}"
echo -e "${CYAN}Please restart your terminal or run the following command to take effect:${NC}"
echo -e "   ${BOLD}source $PROFILE${NC}"
echo ""
