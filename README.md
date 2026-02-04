# znvm (Zig Node Version Manager)

**znvm** 是一个极简、高性能的 Node.js 版本管理器，专为追求速度和简洁的开发者设计。

**znvm** is a minimalist, high-performance Node.js version manager designed for developers who value speed and simplicity.

它结合了 **Zig** 的高性能（用于处理复杂的 SemVer 解析和架构匹配）与 **Shell** 的灵活性（用于环境切换和网络下载），提供极致的体验。

It combines the high performance of **Zig** (handling complex SemVer parsing and architecture matching) with the flexibility of **Shell** (managing environment switching and network downloads) to deliver an ultimate experience.

## ✨ 特性 / Features

- 🚀 **极速 / Blazing Fast**: 核心逻辑由 Zig 编写，启动和解析速度极快。
  - Core logic written in Zig for extremely fast startup and resolution.
- 🧠 **智能 / Smart**: 支持 SemVer 语义化版本（如 `znvm install 18` 自动匹配最新 `v18.x.x`）。
  - Supports SemVer semantic versioning (e.g., `znvm install 18` automatically matches the latest `v18.x.x`).
- 🍎 **Apple Silicon 友好 / Apple Silicon Friendly**: 自动检测架构，并在 Node.js 旧版本（如 v14）缺失 arm64 构建时自动回退到 Rosetta (x64) 模式。
  - Automatically detects architecture and falls back to Rosetta (x64) mode for older Node.js versions (e.g., v14) missing arm64 builds.
- 🐧 **多平台 / Multi-Platform**: 支持 macOS (Apple Silicon/Intel) 和 Linux。
  - Supports macOS (Apple Silicon/Intel) and Linux.
- ⚡ **简洁 / Simple**: 仅需一个命令别名 `nv` 即可完成所有操作。
  - Requires only a single command alias `nv` for all operations.
- 🇨🇳 **本地化 / Localized**: 全中文/英文双语输出提示。
  - Full Chinese/English bilingual output prompts.

## 📦 安装 / Installation

### 自动安装 (推荐) / Automatic Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/main/install.sh | bash
```

### 手动安装 / Manual Installation

1. 克隆仓库：
   Clone the repository:
   ```bash
   git clone https://github.com/charlzyx/znvm.git ~/.znvm
   ```

2. 将以下内容添加到你的 Shell 配置文件 (`~/.zshrc`, `~/.bashrc` 等)：
   Add the following to your Shell configuration file (`~/.zshrc`, `~/.bashrc`, etc.):
   ```bash
   export ZNVM_ROOT="$HOME/.znvm"
   source "$ZNVM_ROOT/znvm.sh"
   
   # 推荐配置别名 / Recommended alias configuration
   alias nv=znvm
   ```

3. 重启 Shell 或执行 `source ~/.zshrc`。
   Restart your Shell or run `source ~/.zshrc`.

**注意**: 初次运行时，znvm 会自动检测并编译核心 Zig 工具（需要安装 [Zig](https://ziglang.org/download/)）。

**Note**: On the first run, znvm will automatically detect and compile the core Zig tools (requires [Zig](https://ziglang.org/download/) installed).

## 🛠 使用指南 / Usage Guide

### 基础命令 / Basic Commands
```bash
# 安装最新的 Node.js 20 / Install latest Node.js 20
znvm install 20

# 切换到 Node.js 18 / Switch to Node.js 18
znvm use 18

# 列出已安装的本地版本 / List installed local versions
znvm ls

# 设置默认版本为 20 (新开终端自动生效) / Set default version to 20 (effective in new terminals)
znvm default 20

# 推荐配置别名后可使用更简短的命令 / Recommended: Use shorter commands after alias config
# alias nv=znvm  # 在 ~/.zshrc 中配置后
# nv install 20
# nv use 18
# nv ls
# nv default 20
```

### 高级配置 / Advanced Configuration

#### 1. 简写别名 / Shorthand Alias
建议配置 `nv` 别名以获得更佳体验：
It is recommended to configure the `nv` alias for a better experience:
```bash
alias nv=znvm
```

#### 2. .nvmrc 支持 / .nvmrc Support
当目录下存在 `.nvmrc` 文件时，执行无参数的 `use` 命令即可自动切换：
When an `.nvmrc` file exists in the directory, running `use` without arguments will automatically switch versions:
```bash
# 假设 .nvmrc 内容为 "18" / Assuming .nvmrc content is "18"
cd my-project
znvm use
# -> 自动切换到 v18.x.x / Automatically switches to v18.x.x
```

#### 3. 镜像源加速 / Mirror Acceleration
支持设置 `NVM_NODEJS_ORG_MIRROR` 环境变量来加速版本解析和下载：
Supports setting the `NVM_NODEJS_ORG_MIRROR` environment variable to accelerate version resolution and downloading:
```bash
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
```

## 🏗 架构设计 / Architecture Design

znvm 采用 **混合架构** (Hybrid Architecture) 设计：
znvm uses a **Hybrid Architecture** design:

1. **Core (Zig)**: `src/main.zig` -> `bin/znvm-core`
   * **职责 / Responsibility**: 负责"纯计算任务" / Handles "pure computation tasks".
   * **功能 / Functions**:
        * 从标准输入 读取 `index.json` 数据。 / Reads `index.json` data from Standard Input (Stdin).
        * 解析复杂的 SemVer 版本号（使用 Zig 标准库 `std.SemanticVersion`）。 / Parses complex SemVer version numbers (using Zig standard library `std.SemanticVersion`).
        * 智能匹配最佳版本（考虑 OS、Arch、Rosetta 回退策略）。 / Intelligently matches the best version (considering OS, Arch, Rosetta fallback strategies).
        * 输出机器可读的结果供 Shell 调用。 / Outputs machine-readable results for Shell invocation.
   * **优势 / Advantages**: 解析 JSON 和版本比 Shell 快且安全；利用 Zig 强大的交叉编译能力。 / Faster and safer JSON/version parsing than Shell; leverages Zig's powerful cross-compilation capabilities.

2. **Shell Wrapper**: `znvm.sh`
   * **职责 / Responsibility**: 负责"IO 与环境操作" / Handles "IO and environment operations".
   * **功能 / Functions**:
        * 管理 `PATH` 环境变量。 / Manages `PATH` environment variables.
        * 使用 `curl` 获取远程版本列表和下载二进制包（自动复用系统代理配置）。 / Uses `curl` to fetch remote version lists and download binaries (automatically reuses system proxy settings).
        * 提供用户交互界面。 / Provides user interaction interface.

```mermaid
flowchart TD
    subgraph Input["输入 / Input"]
        UserCmd["用户命令<br/>znvm install 18 / znvm use"]
        Nvmrc[".nvmrc 文件<br/>(可选 / Optional)"]
        MirrorEnv["NVM_NODEJS_ORG_MIRROR<br/>(镜像源 / Mirror)"]
    end

    Shell["znvm.sh<br/>(Shell Wrapper)"]

    UserCmd --> Shell
    Nvmrc -.->|"读取版本"| Shell
    MirrorEnv -.->|"配置源"| Shell

    Shell -->|"1. curl index.json"| NodeDist["Node.js 镜像站<br/>index.json"]
    NodeDist -->|"2. JSON Stream"| Shell
    Shell -->|"3. Pipe JSON + 版本请求"| ZigCore["znvm-core (Zig Binary)<br/>SemVer 解析 + 架构匹配"]

    ZigCore -->|"4. 返回: 版本 + 架构<br/>e.g. v18.20.4 + arm64/x64"| Shell

    subgraph VersionCheck["版本检查 / Version Check"]
        direction TB
        CheckInstalled{"已安装?"}
        UseExisting["✓ 使用已有版本"]
        NeedDownload["✗ 需要下载"]
    end

    Shell --> CheckInstalled
    CheckInstalled -->|"Yes"| UseExisting
    CheckInstalled -->|"No"| NeedDownload

    NeedDownload -->|"5. curl 下载 tar.gz"| NodeDist
    NodeDist -->|"6. 二进制包"| Shell
    Shell -->|"7. tar 解压"| InstallDir["~/.znvm/versions/<version>"]

    UseExisting --> UpdatePath
    InstallDir --> UpdatePath["8. 更新 PATH"]
    UpdatePath --> Env["当前 Shell 环境<br/>node/npm 可用"]

    style ZigCore fill:#f9f,stroke:#333,stroke-width:2px
    style Shell fill:#bbf,stroke:#333,stroke-width:2px
    style Env fill:#9f9,stroke:#333,stroke-width:2px
```

## 🔨 开发与构建 / Development & Build

如果你想参与开发：
If you want to contribute:

1. 确保安装了 Zig (0.13.0+)。 / Ensure Zig (0.13.0+) is installed.
2. 运行构建： / Run build:
   ```bash
   zig build -Doptimize=ReleaseSafe
   ```

## 📄 License

MIT
