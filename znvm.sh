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
        echo "[znvm] 初始化核心工具..."
        
        # 检查源码目录是否存在 build.zig
        if [[ ! -f "$ZNVM_SOURCE_DIR/build.zig" ]]; then
             echo "[znvm] 错误: 无法在 $ZNVM_SOURCE_DIR 找到源码，无法编译核心工具。"
             return 1
        fi

        echo "[znvm] 编译中..."
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
        echo "[znvm] 初始化完成"
    fi
}


# 内部函数：解析版本并下载安装
function _znvm_install_version() {
    local arg=$1
    local mode=$2 # "install" or "use"

    _znvm_ensure_core || return 1

    # echo "[znvm] 解析版本: $arg"
    
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
        echo "[znvm] 下载 $target_version..."
        
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
        
        curl -L -o "$ZNVM_ROOT/$filename" "$url" --progress-bar
        
        if [[ $? -ne 0 ]]; then
            echo "[znvm] 错误: 下载失败 $url"
            return 1
        fi

        mkdir -p "$version_path"
        tar -xzf "$ZNVM_ROOT/$filename" -C "$version_path" --strip-components=1
        rm "$ZNVM_ROOT/$filename"
        echo "[znvm] 已安装 $target_version"
    else
        echo "[znvm] $target_version 已安装"
    fi

    # 如果是 use 模式，则切换环境
    if [[ "$mode" == "use" ]]; then
        export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$ZNVM_VERSIONS_DIR" | tr '\n' ':')
        export PATH="$version_path/bin:$PATH"
        
        echo "[znvm] node@$(node -v) npm@$(npm -v)"
    fi
}

# 主函数
function znvm() {
    local cmd=$1
    local arg=$2

    if [[ "$cmd" == "list" || "$cmd" == "ls" ]]; then
        if [[ -d "$ZNVM_VERSIONS_DIR" ]]; then
            local installed_versions=$(ls -1 "$ZNVM_VERSIONS_DIR" | grep "v" | sort -V)
            if [[ -z "$installed_versions" ]]; then
                echo "[znvm] (无)"
                return 0
            fi
            
            # 获取当前正在使用的版本
            local current_version=""
            if command -v node &> /dev/null; then
                local node_ver=$(node -v 2>/dev/null)
                if [[ -n "$node_ver" && -d "$ZNVM_VERSIONS_DIR/$node_ver" ]]; then
                    current_version="$node_ver"
                fi
            fi
            
            # 获取默认版本
            local default_version=""
            local default_ver_input=""
            if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
                default_ver_input=$(cat "$ZNVM_ROOT/.default-version" | xargs)
                if [[ -n "$default_ver_input" ]]; then
                    default_version=$(echo "$installed_versions" | "$ZNVM_CORE_BIN" semver match "$default_ver_input" 2>/dev/null)
                fi
            fi

            # 显示版本列表
            while IFS= read -r version; do
                local prefix="  "
                local suffix=""
                if [[ "$version" == "$current_version" ]]; then
                    prefix="->"
                fi
                if [[ "$version" == "$default_version" ]]; then
					suffix="[default]"
                fi
                echo "${prefix} ${version} ${suffix}"
            done <<< "$installed_versions"
        else
            echo "  (无)"
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
            if [[ -f ".nvmrc" ]]; then
                arg=$(head -n 1 .nvmrc | sed 's/#.*//' | xargs)
                if [[ -z "$arg" ]]; then
                    echo "错误: .nvmrc 格式无效"
                    return 1
                fi
                echo "[znvm] 使用.nvmrc: $arg"
            elif [[ -f "$ZNVM_ROOT/.default-version" ]]; then
                arg=$(cat "$ZNVM_ROOT/.default-version" | xargs)
                if [[ -z "$arg" ]]; then
                    echo "错误: default version 格式无效"
                    return 1
                fi
                echo "[znvm] 使用默认值: $arg"
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

    if [[ "$cmd" == "uninstall" || "$cmd" == "rm" ]]; then
        if [[ -z "$arg" ]]; then
            echo "用法: znvm uninstall <version>"
            return 1
        fi

        _znvm_ensure_core || return 1

        # 获取已安装版本列表并匹配
        local installed_versions=$(ls -1 "$ZNVM_VERSIONS_DIR" 2>/dev/null | grep "v" | sort -V)
        if [[ -z "$installed_versions" ]]; then
            echo "[znvm] 没有已安装的版本"
            return 1
        fi

        local target_version=$(echo "$installed_versions" | "$ZNVM_CORE_BIN" semver match "$arg" 2>/dev/null)

        if [[ -z "$target_version" ]]; then
            echo "[znvm] 未找到匹配的版本: $arg"
            return 1
        fi

        local version_path="$ZNVM_VERSIONS_DIR/$target_version"

        if [[ ! -d "$version_path" ]]; then
            echo "[znvm] 版本未安装: $target_version"
            return 1
        fi

        # 检查是否是当前使用的版本
        local current_version=""
        if command -v node &> /dev/null; then
            current_version=$(node -v 2>/dev/null)
        fi

        if [[ "$current_version" == "$target_version" ]]; then
            echo "[znvm] 警告: $target_version 是当前正在使用的版本"
        fi

        # 执行删除
        rm -rf "$version_path"
        echo "[znvm] 已卸载: $target_version"

        # 如果删除的是默认版本，清理 default-version
        if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
            local default_ver_input=$(cat "$ZNVM_ROOT/.default-version" | xargs)
            local default_version=$(echo "$installed_versions" | "$ZNVM_CORE_BIN" semver match "$default_ver_input" 2>/dev/null)
            if [[ "$default_version" == "$target_version" ]]; then
                rm -f "$ZNVM_ROOT/.default-version"
                echo "[znvm] 已清理默认版本设置"
            fi
        fi

        return 0
    fi
    
    echo "znvm <command>"
    echo ""
    echo "Commands:"
    echo "  ls | list              列出已安装版本"
    echo "  install <ver>   安装版本"
    echo "  rm | uninstall <ver> 卸载版本"
    echo "  use [ver]       切换版本 (读取 .nvmrc -> default)"
    echo "  default <ver>   设置默认版本"
}

# 自动加载默认版本
if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
    znvm use "$(cat "$ZNVM_ROOT/.default-version")" > /dev/null 2>&1
fi
