#!/bin/zsh
# znvm - 一个基于 Zig 的极简 Node 版本管理器
# 用法: source znvm.sh
# 别名: nv

# 设定源码目录 (用于编译)
if [[ -n "${ZSH_VERSION}" ]]; then
    ZNVM_SOURCE_DIR=${0:A:h}
else
    ZNVM_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# 设定运行时根目录
if [[ -z "$ZNVM_ROOT" ]]; then
    ZNVM_ROOT="$HOME/.znvm"
fi

# 数据目录
ZNVM_VERSIONS_DIR="$ZNVM_ROOT/versions"
ZNVM_BIN_DIR="$ZNVM_ROOT/bin"
ZNVM_CORE_BIN="$ZNVM_BIN_DIR/znvm-core"

# 确保目录存在
mkdir -p "$ZNVM_VERSIONS_DIR"
mkdir -p "$ZNVM_BIN_DIR"

# 检查并编译 Zig 核心工具
function _znvm_ensure_core() {
    if [[ ! -f "$ZNVM_CORE_BIN" ]]; then
        echo "正在初始化 znvm 核心工具... / Initializing znvm core tools..."
        
        # 检查源码目录是否存在 build.zig
        if [[ ! -f "$ZNVM_SOURCE_DIR/build.zig" ]]; then
             echo "错误: 无法在 $ZNVM_SOURCE_DIR 找到源码，无法编译核心工具。"
             echo "Error: Source not found in $ZNVM_SOURCE_DIR, cannot compile core tools."
             return 1
        fi

        echo "正在编译 (zig)... / Compiling (zig)..."
        pushd "$ZNVM_SOURCE_DIR" > /dev/null
        zig build -Doptimize=ReleaseSafe
        if [[ $? -ne 0 ]]; then
            echo "错误: Zig 编译失败。"
            echo "Error: Zig compilation failed."
            popd > /dev/null
            return 1
        fi
        
        # 安装二进制文件到 ~/.znvm/bin
        cp "$ZNVM_SOURCE_DIR/zig-out/bin/znvm-core" "$ZNVM_CORE_BIN"
        
        popd > /dev/null
        echo "初始化完成。 / Initialization completed."
    fi
}


# 内部函数：解析版本并下载安装
function _znvm_install_version() {
    local arg=$1
    local mode=$2 # "install" or "use"

    _znvm_ensure_core || return 1

    echo "正在解析版本 '$arg'... / Resolving version '$arg'..."
    
    # 镜像源处理: 优先使用环境变量，否则默认使用 npmmirror (国内优化)
    local index_mirror="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node}"
    index_mirror="${index_mirror%/}"
    
    local resolve_result=$(curl -sL -H "User-Agent: znvm/1.0.0" "$index_mirror/index.json" | "$ZNVM_CORE_BIN" resolve "$arg")
    
    if [[ $? -ne 0 || -z "$resolve_result" ]]; then
        echo "错误: 无法解析版本 '$arg'"
        echo "Error: Failed to resolve version '$arg'"
        echo "$resolve_result"
        return 1
    fi

    local target_version=$(echo "$resolve_result" | awk '{print $1}')
    local target_arch=$(echo "$resolve_result" | awk '{print $2}')

    if [[ -z "$target_version" || -z "$target_arch" ]]; then
            echo "错误: 解析输出格式异常: $resolve_result"
            echo "Error: Abnormal resolution output format: $resolve_result"
            return 1
    fi

    echo "目标版本: $target_version ($target_arch) / Target: $target_version ($target_arch)"

    local version_path="$ZNVM_VERSIONS_DIR/$target_version"
    
    if [[ ! -d "$version_path" ]]; then
        echo "版本 $target_version 未安装，正在下载..."
        echo "Version $target_version not installed, downloading..."
        
        local os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
        local os=""
        if [[ "$os_type" == "darwin" ]]; then
            os="darwin"
        elif [[ "$os_type" == "linux" ]]; then
            os="linux"
        else
            echo "错误: 不支持的操作系统 '$os_type'"
            echo "Error: Unsupported OS '$os_type'"
            return 1
        fi
        
        # 镜像源处理: 优先使用环境变量，否则默认使用 npmmirror (国内优化)
        local mirror="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node}"
        # 去除末尾斜杠
        mirror="${mirror%/}"
        
        local filename="node-${target_version}-${os}-${target_arch}.tar.gz"
        local url="${mirror}/${target_version}/${filename}"
        
        echo "下载地址: $url / Downloading from: $url"
        
        curl -L -o "$ZNVM_ROOT/$filename" "$url"
        
        if [[ $? -ne 0 ]]; then
            echo "下载失败。 / Download failed."
            return 1
        fi

        echo "正在解压... / Extracting..."
        mkdir -p "$version_path"
        tar -xzf "$ZNVM_ROOT/$filename" -C "$version_path" --strip-components=1
        rm "$ZNVM_ROOT/$filename"
        echo "安装完成: $target_version / Installation complete: $target_version"
    else
        echo "版本 $target_version 已安装。 / Version $target_version already installed."
    fi

    # 如果是 use 模式，则切换环境
    if [[ "$mode" == "use" ]]; then
        export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$ZNVM_VERSIONS_DIR" | tr '\n' ':')
        export PATH="$version_path/bin:$PATH"
        
        echo "已切换到 Node.js $target_version / Switched to Node.js $target_version"
        node -v
    fi
}

# 主函数
function znvm() {
    local cmd=$1
    local arg=$2

    if [[ "$cmd" == "ls" ]]; then
        echo "已安装的版本: / Installed versions:"
        if [[ -d "$ZNVM_VERSIONS_DIR" ]]; then
             ls -1 "$ZNVM_VERSIONS_DIR" | grep "v" || echo "(无 / None)"
        else
            echo "(无 / None)"
        fi
        return 0
    fi

    if [[ "$cmd" == "install" ]]; then
        if [[ -z "$arg" ]]; then
            echo "用法: znvm install <version> / Usage: znvm install <version>"
            return 1
        fi
        _znvm_install_version "$arg" "install"
        return
    fi

    if [[ "$cmd" == "use" ]]; then
        if [[ -z "$arg" ]]; then
            # 尝试读取 .nvmrc
            if [[ -f ".nvmrc" ]]; then
                # 读取第一行，去除注释 (#之后的内容)，并去除首尾空白
                arg=$(head -n 1 .nvmrc | sed 's/#.*//' | xargs)
                if [[ -z "$arg" ]]; then
                    echo "错误: .nvmrc 文件为空或格式无效 / Error: .nvmrc file is empty or invalid"
                    return 1
                fi
                echo "发现 .nvmrc: 使用版本 $arg / Found .nvmrc: using version $arg"
            else
                echo "用法: znvm use <version> / Usage: znvm use <version>"
                return 1
            fi
        fi
        _znvm_install_version "$arg" "use"
        return
    fi

    if [[ "$cmd" == "default" ]]; then
        if [[ -z "$arg" ]]; then
            echo "用法: znvm default <version> / Usage: znvm default <version>"
            return 1
        fi
        echo "$arg" > "$ZNVM_ROOT/.default-version"
        echo "默认版本已设置为 $arg / Default version set to $arg"
        return
    fi
    
    echo "用法: znvm [ls | use <ver> | default <ver>] / Usage: znvm [ls | use <ver> | default <ver>]"
}

# 自动加载默认版本
if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
    znvm use "$(cat "$ZNVM_ROOT/.default-version")" > /dev/null 2>&1
fi
