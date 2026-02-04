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
        echo "[znvm] 正在初始化核心工具..."
        
        # 检查源码目录是否存在 build.zig
        if [[ ! -f "$ZNVM_SOURCE_DIR/build.zig" ]]; then
             echo "[znvm] 错误: 无法在 $ZNVM_SOURCE_DIR 找到源码，无法编译核心工具。"
             return 1
        fi

        echo "[znvm] 编译中 (zig)..."
        pushd "$ZNVM_SOURCE_DIR" > /dev/null
        zig build -Doptimize=ReleaseSafe
        if [[ $? -ne 0 ]]; then
            echo "[znvm] 错误: Zig 编译失败。"
            popd > /dev/null
            return 1
        fi
        
        # 安装二进制文件到 ~/.znvm/bin
        cp "$ZNVM_SOURCE_DIR/zig-out/bin/znvm-core" "$ZNVM_CORE_BIN"
        
        popd > /dev/null
        echo "[znvm] 初始化完成。"
    fi
}

# 内部函数：卸载版本
function _znvm_uninstall_version() {
    local arg=$1

    if [[ -z "$arg" ]]; then
        echo "用法: znvm uninstall <version>"
        return 1
    fi

    _znvm_ensure_core || return 1

    echo "[znvm] 解析版本: $arg"

    # 从本地已安装的版本列表中匹配
    local installed_versions=$(ls -1 "$ZNVM_VERSIONS_DIR" 2>/dev/null | grep "^v" | sort -V)

    if [[ -z "$installed_versions" ]]; then
        echo "[znvm] 错误: 没有已安装的版本"
        return 1
    fi

    # 将版本列表传给 znvm-core 进行匹配
    local target_version=$(echo "$installed_versions" | "$ZNVM_CORE_BIN" semver match "$arg")

    if [[ -z "$target_version" ]]; then
        echo "[znvm] 错误: 无法在已安装版本中找到匹配 '$arg'"
        echo "[znvm] 已安装的版本:"
        echo "$installed_versions" | sed 's/^/  /'
        return 1
    fi

    echo "[znvm] 目标版本: $target_version"

    local version_path="$ZNVM_VERSIONS_DIR/$target_version"
    
    if [[ ! -d "$version_path" ]]; then
        echo "[znvm] 错误: 版本 $target_version 未安装"
        return 1
    fi
    
    # 检查是否是当前正在使用的版本
    local is_current=false
    if command -v node &> /dev/null; then
        local node_path=$(which node)
        if [[ -n "$node_path" && "$node_path" == "$version_path/bin/node" ]]; then
            is_current=true
        fi
    fi
    
    if [[ "$is_current" == true ]]; then
        echo "[znvm] 警告: 当前正在使用此版本，卸载后需要重新安装或切换其他版本"
    fi
    
    echo "[znvm] 正在卸载: $version_path"
    rm -rf "$version_path"
    
    if [[ $? -ne 0 ]]; then
        echo "[znvm] 错误: 卸载失败"
        return 1
    fi
    
    # 如果是默认版本，清除默认配置
    if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
        local default_ver_input=$(cat "$ZNVM_ROOT/.default-version" | xargs)
        # 简单匹配：如果输入是部分版本号（如18），检查默认版本是否以18开头
        if [[ -n "$default_ver_input" && "$target_version" == "$default_ver_input"* ]]; then
            rm "$ZNVM_ROOT/.default-version"
            echo "[znvm] 已清除默认版本配置"
        elif [[ "$target_version" == "$default_ver_input" ]]; then
            rm "$ZNVM_ROOT/.default-version"
            echo "[znvm] 已清除默认版本配置"
        fi
    fi
    
    echo "[znvm] 已卸载: $target_version"
}

# 内部函数：解析版本并下载安装
function _znvm_install_version() {
    local arg=$1
    local mode=$2 # "install" or "use"

    _znvm_ensure_core || return 1

    echo "[znvm] 解析版本: $arg"
    
    # 镜像源处理: 优先使用环境变量，否则默认使用 npmmirror (国内优化)
    local index_mirror="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node}"
    index_mirror="${index_mirror%/}"
    
    local resolve_result=$(curl -sL -H "User-Agent: znvm/1.0.0" "$index_mirror/index.json" | "$ZNVM_CORE_BIN" resolve "$arg")
    
    if [[ $? -ne 0 || -z "$resolve_result" ]]; then
        echo "[znvm] 错误: 无法解析版本 '$arg'"
        echo "$resolve_result"
        return 1
    fi

    local target_version=$(echo "$resolve_result" | awk '{print $1}')
    local target_arch=$(echo "$resolve_result" | awk '{print $2}')

    if [[ -z "$target_version" || -z "$target_arch" ]]; then
            echo "[znvm] 错误: 解析输出格式异常: $resolve_result"
            return 1
    fi

    echo "[znvm] ${arg} -> $target_version ($target_arch)"

    local version_path="$ZNVM_VERSIONS_DIR/$target_version"
    
    if [[ ! -d "$version_path" ]]; then
        echo "[znvm] 版本 $target_version 未安装，正在下载..."
        
        local os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
        local os=""
        if [[ "$os_type" == "darwin" ]]; then
            os="darwin"
        elif [[ "$os_type" == "linux" ]]; then
            os="linux"
        else
            echo "[znvm] 错误: 不支持的操作系统 '$os_type'"
            return 1
        fi
        
        # 镜像源处理: 优先使用环境变量，否则默认使用 npmmirror (国内优化)
        local mirror="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node}"
        mirror="${mirror%/}"
        
        local filename="node-${target_version}-${os}-${target_arch}.tar.gz"
        local url="${mirror}/${target_version}/${filename}"
        
        echo "[znvm] 下载地址: $url"
        
        curl -L -o "$ZNVM_ROOT/$filename" "$url" --progress-bar
        
        if [[ $? -ne 0 ]]; then
            echo "[znvm] 错误: 下载失败"
            return 1
        fi

        echo "[znvm] 正在解压..."
        mkdir -p "$version_path"
        tar -xzf "$ZNVM_ROOT/$filename" -C "$version_path" --strip-components=1
        rm "$ZNVM_ROOT/$filename"
        echo "[znvm] 已安装: $target_version"
    else
        echo "[znvm] 版本 $target_version 已安装。"
    fi

    # 如果是 use 模式，则切换环境
    if [[ "$mode" == "use" ]]; then
        export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$ZNVM_VERSIONS_DIR" | tr '\n' ':')
        export PATH="$version_path/bin:$PATH"
        
        echo "[znvm] 已切换到 Node.js $target_version"
        node -v
    fi
}

# 主函数
function znvm() {
    local cmd=$1
    local arg=$2

    if [[ "$cmd" == "ls" ]]; then
        if [[ -d "$ZNVM_VERSIONS_DIR" ]]; then
            local installed_versions=$(ls -1 "$ZNVM_VERSIONS_DIR" | grep "v" | sort -V)
            if [[ -z "$installed_versions" ]]; then
                echo "[znvm] (无)"
                return 0
            fi
            
            # 获取当前正在使用的版本
            local current_version=""
            if command -v node &> /dev/null; then
                local node_path=$(which node)
                if [[ -n "$node_path" && "$node_path" == "$ZNVM_VERSIONS_DIR"* ]]; then
                    current_version=$(basename "$(dirname "$node_path")")
                fi
            fi
            
            # 获取默认版本
            local default_version=""
            if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
                local default_ver_input=$(cat "$ZNVM_ROOT/.default-version" | xargs)
                if [[ -n "$default_ver_input" ]]; then
                    default_version=$(echo "$installed_versions" | grep "^v${default_ver_input}\." | head -1)
                fi
            fi
            
            # 显示版本列表，标记当前和默认
            echo "$installed_versions" | while read -r version; do
                local markers=""
                if [[ "$version" == "$current_version" ]]; then
                    markers="->"
                fi
                if [[ "$version" == "$default_version" ]]; then
                    markers="${markers} [default]"
                fi
                echo "  ${markers} ${version}"
            done
        else
            echo "[znvm] (无)"
        fi
        return 0
    fi

    if [[ "$cmd" == "install" ]]; then
        if [[ -z "$arg" ]]; then
            echo "用法: znvm install <version>"
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
                    echo "[znvm] 错误: .nvmrc 文件为空或格式无效"
                    return 1
                fi
                echo "[znvm] 发现 .nvmrc: 使用版本 $arg"
            else
                echo "用法: znvm use <version>"
                return 1
            fi
        fi
        _znvm_install_version "$arg" "use"
        return
    fi

    if [[ "$cmd" == "default" ]]; then
        if [[ -z "$arg" ]]; then
            echo "用法: znvm default <version>"
            return 1
        fi
        echo "$arg" > "$ZNVM_ROOT/.default-version"
        echo "[znvm] 设置默认版本: $arg (在新会话中生效)"
        return
    fi

    if [[ "$cmd" == "uninstall" ]]; then
        if [[ -z "$arg" ]]; then
            echo "用法: znvm uninstall <version>"
            return 1
        fi
        _znvm_uninstall_version "$arg"
        return
    fi
    
    echo "znvm <command>"
    echo ""
    echo "Commands:"
    echo "  ls              列出已安装版本 (list)"
    echo "  install <ver>   安装版本"
    echo "  use [ver]       切换版本 (读取 .nvmrc)"
    echo "  default <ver>   设置默认版本"
    echo "  uninstall <ver> 卸载版本 (uninstall)"
}

# 自动加载默认版本
if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
    znvm use "$(cat "$ZNVM_ROOT/.default-version")" > /dev/null 2>&1
fi
