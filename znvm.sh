
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

# ========== 公共辅助函数 ==========

# 获取镜像源 URL
function _znvm_get_mirror() {
    local mirror="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node}"
    echo "${mirror%/}"
}

# 获取当前使用的 node 版本
function _znvm_get_current_version() {
    if command -v node &> /dev/null; then
        node -v 2>/dev/null
    fi
}

# 获取已安装版本列表（只返回 bin/node 存在的有效版本）
function _znvm_get_installed_versions() {
    local versions=()
    # 使用 (N) glob 修饰符避免无匹配时报错
    for dir in "$ZNVM_VERSIONS_DIR"/v*(N); do
        if [[ -d "$dir" && -f "$dir/bin/node" ]]; then
            versions+=("$(basename "$dir")")
        fi
    done
    if [[ ${#versions[@]} -gt 0 ]]; then
        printf '%s\n' "${versions[@]}" | sort -V
    fi
}

# 使用 semver 匹配版本
function _znvm_semver_match() {
    local versions="$1"
    local pattern="$2"
    echo "$versions" | "$ZNVM_CORE_BIN" semver match "$pattern" 2>/dev/null
}

# 获取版本路径
function _znvm_version_path() {
    echo "$ZNVM_VERSIONS_DIR/$1"
}

# 打印错误信息
function _znvm_error() {
    echo "[znvm] 错误: $1" >&2
}

# 打印信息
function _znvm_info() {
    echo "[znvm] $1"
}

# 检查并编译 Zig 核心工具
function _znvm_ensure_core() {
    if [[ ! -f "$ZNVM_CORE_BIN" ]]; then
        _znvm_info "初始化核心工具..."

        # 检查源码目录是否存在 build.zig
        if [[ ! -f "$ZNVM_SOURCE_DIR/build.zig" ]]; then
            _znvm_error "无法在 $ZNVM_SOURCE_DIR 找到源码，无法编译核心工具。"
            return 1
        fi

        _znvm_info "编译中..."
        pushd "$ZNVM_SOURCE_DIR" > /dev/null
        if ! zig build -Doptimize=ReleaseSafe; then
            _znvm_error "Zig 编译失败。"
            popd > /dev/null
            return 1
        fi

        # 安装二进制文件到 ~/.znvm/bin
        cp "$ZNVM_SOURCE_DIR/zig-out/bin/znvm-core" "$ZNVM_CORE_BIN"

        popd > /dev/null
        _znvm_info "初始化完成"
    fi
}


# 检测本地是否有匹配的 node 版本
# 返回匹配的版本号，如果没有则返回空
function _znvm_find_local_version() {
    local arg=$1
    _znvm_ensure_core || return 1

    local installed_versions=$(_znvm_get_installed_versions)
    if [[ -z "$installed_versions" ]]; then
        return
    fi

    _znvm_semver_match "$installed_versions" "$arg"
}

# 内部函数：切换版本环境
function _znvm_switch_version() {
    local target_version=$1
    local version_path=$(_znvm_version_path "$target_version")

    # 验证目标版本的 node 是否存在
    if [[ ! -x "$version_path/bin/node" ]]; then
        _znvm_error "版本 $target_version 的 node 可执行文件不存在或不可执行"
        return 1
    fi

    # 过滤掉已存在的 znvm 版本路径（zsh 用 ${(s/:/)PATH} 分割）
    local new_path=""
    local path_entries=(${(s/:/)PATH})
    for p in "${path_entries[@]}"; do
        if [[ -n "$p" && "$p" != *"$ZNVM_VERSIONS_DIR"* ]]; then
            if [[ -z "$new_path" ]]; then
                new_path="$p"
            else
                new_path="$new_path:$p"
            fi
        fi
    done
    export PATH="$version_path/bin:$new_path"

    # hash -r 清除命令缓存，确保使用新版本的 node
    hash -r 2>/dev/null || true

    # npm 配置：全局安装路径和缓存目录（每个版本独立）
    export NPM_CONFIG_PREFIX="$version_path"
    export NPM_CONFIG_CACHE="$version_path/.npm"

    # Corepack 配置：保持每个版本的包管理器独立
    export COREPACK_HOME="$version_path/.corepack"

    _znvm_info "node@$(node -v) npm@$(npm -v)"
}

# 获取操作系统类型
function _znvm_get_os() {
    local os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$os_type" in
        darwin) echo "darwin" ;;
        linux)  echo "linux" ;;
        *)      echo "" ;;
    esac
}

# 清理下载文件
function _znvm_cleanup_download() {
    local filename="$1"
    rm -f "$ZNVM_ROOT/$filename"
}

# 内部函数：解析版本并下载安装
function _znvm_install_version() {
    local arg=$1
    local mode=$2 # "install" or "use"

    _znvm_ensure_core || return 1

    local index_mirror=$(_znvm_get_mirror)
    local resolve_result

    resolve_result=$(curl -sL -H "User-Agent: znvm/1.0.0" "$index_mirror/index.json" 2>/dev/null | "$ZNVM_CORE_BIN" resolve "$arg")

    if [[ $? -ne 0 || -z "$resolve_result" ]]; then
        _znvm_error "无法解析版本 '$arg'"
        echo "$resolve_result"
        return 1
    fi

    local target_version=$(echo "$resolve_result" | awk '{print $1}')
    local target_arch=$(echo "$resolve_result" | awk '{print $2}')

    if [[ -z "$target_version" || -z "$target_arch" ]]; then
        _znvm_error "解析输出格式异常: $resolve_result"
        return 1
    fi

    _znvm_info "${arg} -> $target_version ($target_arch)"

    local version_path=$(_znvm_version_path "$target_version")

    # 如果目录不存在或 node 不存在，需要安装
    if [[ ! -d "$version_path" || ! -f "$version_path/bin/node" ]]; then
        # 如果目录存在但 node 不存在，清理它
        if [[ -d "$version_path" ]]; then
            rm -rf "$version_path"
        fi

        _znvm_info "下载 $target_version..."

        local os=$(_znvm_get_os)
        if [[ -z "$os" ]]; then
            _znvm_error "不支持的操作系统 '$(uname -s)'"
            return 1
        fi

        local mirror=$(_znvm_get_mirror)
        local filename="node-${target_version}-${os}-${target_arch}.tar.gz"
        local url="${mirror}/${target_version}/${filename}"

        if ! curl -L -f --connect-timeout 30 --max-time 300 --retry 2 \
                  -o "$ZNVM_ROOT/$filename" "$url" --progress-bar 2>/dev/null; then
            _znvm_error "下载失败 $url"
            _znvm_cleanup_download "$filename"
            return 1
        fi

        # 验证文件是有效的 tar.gz
        if ! tar -tzf "$ZNVM_ROOT/$filename" > /dev/null 2>&1; then
            _znvm_error "下载文件格式无效，可能镜像源没有该版本"
            _znvm_cleanup_download "$filename"
            return 1
        fi

        mkdir -p "$version_path"
        if ! tar -xzf "$ZNVM_ROOT/$filename" -C "$version_path" --strip-components=1; then
            _znvm_error "解压失败"
            rm -rf "$version_path"
            _znvm_cleanup_download "$filename"
            return 1
        fi

        # 验证解压后 node 是否存在
        if [[ ! -f "$version_path/bin/node" ]]; then
            _znvm_error "解压后未找到 node 可执行文件"
            rm -rf "$version_path"
            _znvm_cleanup_download "$filename"
            return 1
        fi

        _znvm_cleanup_download "$filename"
        _znvm_info "已安装 $target_version"
    else
        # 在 use 模式下不重复提示已安装
        if [[ "$mode" != "use" ]]; then
            _znvm_info "$target_version 已安装"
        fi
    fi

    # 如果是 use 模式，则切换环境
    if [[ "$mode" == "use" ]]; then
        _znvm_switch_version "$target_version"
        return $?
    fi
}

# 主函数
function znvm() {
    local cmd=$1
    local arg=$2

    if [[ "$cmd" == "list" || "$cmd" == "ls" ]]; then
        if [[ -d "$ZNVM_VERSIONS_DIR" ]]; then
            local installed_versions=$(_znvm_get_installed_versions)
            if [[ -z "$installed_versions" ]]; then
                _znvm_info "(无)"
                return 0
            fi

            # 获取当前正在使用的版本
            local current_version=$(_znvm_get_current_version)
            if [[ -n "$current_version" && ! -d "$ZNVM_VERSIONS_DIR/$current_version" ]]; then
                current_version=""
            fi

            # 获取默认版本
            local default_version=""
            local default_ver_input=""
            if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
                default_ver_input=$(cat "$ZNVM_ROOT/.default-version" | xargs)
                if [[ -n "$default_ver_input" ]]; then
                    default_version=$(_znvm_semver_match "$installed_versions" "$default_ver_input")
                fi
            fi

            # 显示版本列表
            echo "$installed_versions" | while IFS= read -r version; do
                local prefix="  "
                local suffix=""
                if [[ -n "$version" && "$version" == "$current_version" ]]; then
                    prefix="->"
                fi
                if [[ -n "$version" && "$version" == "$default_version" ]]; then
                    suffix="[default]"
                fi
                echo "${prefix} ${version} ${suffix}"
            done
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
        return $?
    fi

    if [[ "$cmd" == "use" ]]; then
        if [[ -z "$arg" ]]; then
            if [[ -f ".nvmrc" ]]; then
                arg=$(head -n 1 .nvmrc | sed 's/#.*//' | xargs)
                if [[ -z "$arg" ]]; then
                    _znvm_error ".nvmrc 格式无效"
                    return 1
                fi
                _znvm_info "使用.nvmrc: $arg"
            elif [[ -f "$ZNVM_ROOT/.default-version" ]]; then
                arg=$(cat "$ZNVM_ROOT/.default-version" | xargs)
                if [[ -z "$arg" ]]; then
                    _znvm_error "default version 格式无效"
                    return 1
                fi
                _znvm_info "使用默认值: $arg"
            else
                echo "用法: znvm use <version>"
                return 1
            fi
        fi

        # use 命令：先检测本地已安装版本
        local local_version=$(_znvm_find_local_version "$arg")

        if [[ -n "$local_version" ]]; then
            # 本地有，直接切换
            _znvm_info "${arg} -> $local_version (本地已安装)"
            _znvm_switch_version "$local_version"
        else
            # 本地没有，下载安装
            _znvm_install_version "$arg" "use"
        fi
        return $?
    fi

    if [[ "$cmd" == "default" ]]; then
        if [[ -z "$arg" ]]; then
            echo "用法: znvm default <version>"
            return 1
        fi
        echo "$arg" > "$ZNVM_ROOT/.default-version"
        _znvm_info "设置默认版本: $arg (在新会话中生效)"
        return 0
    fi

    if [[ "$cmd" == "list-global" || "$cmd" == "lg" ]]; then
        local current_version=$(_znvm_get_current_version)

        if [[ -z "$current_version" ]]; then
            _znvm_error "没有正在使用的 Node 版本"
            return 1
        fi

        local global_modules_dir="$ZNVM_VERSIONS_DIR/$current_version/lib/node_modules"
        if [[ ! -d "$global_modules_dir" ]]; then
            _znvm_info "没有全局安装的包"
            return 0
        fi

        _znvm_info "$current_version 全局包:"
        ls "$global_modules_dir" 2>/dev/null | grep -vE '^(npm|corepack|npx)$' | while read -r pkg; do
            if [[ -d "$global_modules_dir/$pkg" ]]; then
                echo "  $pkg"
            fi
        done
        return 0
    fi

    if [[ "$cmd" == "uninstall" || "$cmd" == "rm" ]]; then
        if [[ -z "$arg" ]]; then
            echo "用法: znvm uninstall <version>"
            return 1
        fi

        _znvm_ensure_core || return 1

        # 获取已安装版本列表并匹配
        local installed_versions=$(_znvm_get_installed_versions)
        if [[ -z "$installed_versions" ]]; then
            _znvm_error "没有已安装的版本"
            return 1
        fi

        local target_version=$(_znvm_semver_match "$installed_versions" "$arg")

        if [[ -z "$target_version" ]]; then
            _znvm_error "未找到匹配的版本: $arg"
            return 1
        fi

        local version_path=$(_znvm_version_path "$target_version")

        if [[ ! -d "$version_path" ]]; then
            _znvm_error "版本未安装: $target_version"
            return 1
        fi

        # 检查是否是当前使用的版本
        local current_version=$(_znvm_get_current_version)

        if [[ "$current_version" == "$target_version" ]]; then
            _znvm_info "警告: $target_version 是当前正在使用的版本"
        fi

        # 检查是否有全局安装的包
        local global_modules_dir="$version_path/lib/node_modules"
        if [[ -d "$global_modules_dir" ]]; then
            # 排除 npm/corepack 等系统包
            local global_packages=$(ls "$global_modules_dir" 2>/dev/null | grep -vE '^(npm|corepack|npx)$' | head -10)
            if [[ -n "$global_packages" ]]; then
                _znvm_info "该版本有以下全局包:"
                echo "$global_packages" | while read -r pkg; do
                    echo "  - $pkg"
                done
                local pkg_count=$(ls "$global_modules_dir" 2>/dev/null | grep -vE '^(npm|corepack|npx)$' | wc -l)
                if [[ $pkg_count -gt 10 ]]; then
                    echo "  ... 还有 $((pkg_count - 10)) 个"
                fi
                _znvm_info "使用 'nv list-global' 查看完整列表"
            fi
        fi

        # 执行删除
        rm -rf "$version_path"
        _znvm_info "已卸载: $target_version"

        # 如果删除的是默认版本，清理 default-version
        if [[ -f "$ZNVM_ROOT/.default-version" ]]; then
            local default_ver_input=$(cat "$ZNVM_ROOT/.default-version" | xargs)
            local default_version=$(_znvm_semver_match "$installed_versions" "$default_ver_input")
            if [[ "$default_version" == "$target_version" ]]; then
                rm -f "$ZNVM_ROOT/.default-version"
                _znvm_info "已清理默认版本设置"
            fi
        fi

        return 0
    fi
    
    echo "znvm <command>"
    echo ""
    echo "Commands:"
    echo "  ls | list              列出已安装版本"
    echo "  install <ver>          安装版本"
    echo "  rm | uninstall <ver>   卸载版本"
    echo "  use [ver]              切换版本 (读取 .nvmrc -> default)"
    echo "  default <ver>          设置默认版本"
    echo "  lg | list-global       列出当前版本全局包"
}

# 自动加载版本（优先级: .nvmrc > default-version）
if [[ -f ".nvmrc" ]]; then
    znvm use > /dev/null 2>&1
elif [[ -f "$ZNVM_ROOT/.default-version" ]]; then
    znvm use "$(cat "$ZNVM_ROOT/.default-version")" > /dev/null 2>&1
fi