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
ZNVM_VERSION="v2.1.0"

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
echo -e "${CYAN}=> Binary will be installed to $INSTALL_BIN_DIR${NC}"

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
        DOWNLOAD_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/znvm-$VERSION-$TARGET"

        echo -e "${CYAN}=> 尝试下载预编译二进制文件 ($TARGET)...${NC}"
        echo -e "${CYAN}=> Attempting to download pre-compiled binary ($TARGET)...${NC}"

        if curl -L -o "$INSTALL_BIN_DIR/znvm" "$DOWNLOAD_URL" --fail 2>/dev/null; then
            chmod +x "$INSTALL_BIN_DIR/znvm"
            BINARY_DOWNLOADED=true
            echo -e "${GREEN}✔ 二进制文件下载成功！${NC}"
            echo -e "${GREEN}✔ Binary downloaded successfully!${NC}"
        else
            echo -e "${RED}✘ 预编译二进制文件下载失败。${NC}"
            echo -e "${RED}✘ Failed to download pre-compiled binary.${NC}"
            rm -f "$INSTALL_BIN_DIR/znvm"
        fi
    else
        echo -e "${RED}✘ 无法获取版本信息。${NC}"
        echo -e "${RED}✘ Failed to get version info.${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 未找到当前平台的预编译版本。${NC}"
    echo -e "${YELLOW}⚠ No pre-compiled binary found for current platform.${NC}"
fi

# 2. 如果下载失败，直接报错退出
if [ "$BINARY_DOWNLOADED" = false ]; then
    echo ""
    echo -e "${RED}${BOLD}✘ 安装失败 / Installation failed${NC}"
    echo ""
    echo -e "${YELLOW}原因: 当前平台 (${OS}/${ARCH}) 暂无可用的预编译二进制文件。${NC}"
    echo -e "${YELLOW}Reason: No pre-compiled binary available for current platform (${OS}/${ARCH}).${NC}"
    echo ""
    echo -e "${CYAN}您可以尝试以下解决方案 / You can try the following solutions:${NC}"
    echo ""
    echo -e "${CYAN}1. 手动编译安装 / Compile manually:${NC}"
    echo -e "   git clone $REPO_URL $ZNVM_DIR"
    echo -e "   cd $ZNVM_DIR"
    echo -e "   zig build -Doptimize=ReleaseFast"
    echo -e "   cp zig-out/bin/znvm $INSTALL_BIN_DIR/znvm"
    echo ""
    echo -e "${CYAN}2. 或者等待官方支持 / Or wait for official support:${NC}"
    echo -e "   在 GitHub 提交 issue 请求支持 ${OS}/${ARCH} 平台${NC}"
    echo -e "   Submit an issue on GitHub to request ${OS}/${ARCH} support${NC}"
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
    echo -e "${GREEN}✔ znvm 已在 $PROFILE 中配置。${NC}"
    echo -e "${GREEN}✔ znvm is already configured in $PROFILE.${NC}"
else
    echo -e "${CYAN}=> 添加配置到 $PROFILE...${NC}"
    echo -e "${CYAN}=> Adding configuration to $PROFILE...${NC}"
    echo "" >> "$PROFILE"
    echo "# znvm" >> "$PROFILE"
    echo "$SOURCE_STR" >> "$PROFILE"
fi

echo ""
echo -e "${GREEN}${BOLD}🎉 安装成功！${NC}"
echo -e "${GREEN}${BOLD}🎉 Installation successful!${NC}"
echo -e "${CYAN}请重新打开终端或运行以下命令生效：${NC}"
echo -e "${CYAN}Please restart your terminal or run the following command to take effect:${NC}"
echo -e "   ${BOLD}source $PROFILE${NC}"
echo ""
