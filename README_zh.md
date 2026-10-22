# znvm (Zig Node Version Manager)

**基于 Zig 的 Node.js 版本管理器。日常命令对齐 nvm，版本放在 `~/.nvm`，下载默认走 npmmirror。**

[![GitHub stars](https://img.shields.io/github/stars/charlzyx/znvm.svg?style=social)](https://github.com/charlzyx/znvm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Language: Zig](https://img.shields.io/badge/Language-Zig-f7a41d.svg)](https://ziglang.org/)

---

## 🚀 为什么选择 znvm?

**znvm** 是面向日常 nvm 用法的 Zig 版 Node.js 版本管理器。默认下载镜像是 npmmirror。下面的性能对比是实测，不是口号。

- **实测启动**: 2026-10-22，暖 shell 启动中位数是 znvm **3.31 ms**、fnm **1.58 ms**、nvm **113 ms**。每次丢掉页缓存后，中位数是 **5.01 ms**、**4.70 ms**、**121 ms**。p95 和 shell 内命令见下面的性能对比。
- **零配置**: 完美支持 `.nvmrc`。只需 `cd` 进入目录，环境立即就绪。
- **极简专注**: 无冗余依赖，无 Windows 平台的沉重抽象。纯粹为 Unix 性能而生。
- **智能架构**: Zig 核心处理复杂的 SemVer 解析；Shell 脚本负责环境切换。

## 📦 快速安装

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/main/install-as-nvm.sh | bash
```

脚本会安装 `nvm` 命令并写入 `~/.nvm/nvm.sh`。可以重复执行：不会重复写入 shell 配置，也不会删除 `~/.nvm/versions/node` 里已有的 Node。不会安装 shell 补全。

结束后会打印：

```text
nvm is ready.

Open a new terminal, or run:
  source "~/.bashrc"

export NVM_DIR="$HOME/.nvm"
nvm install 22
nvm use 22
nvm ls

Node versions are stored in $NVM_DIR/versions/node.
Downloads use https://npmmirror.com/mirrors/node unless NVM_NODEJS_ORG_MIRROR is set.
```

`source` 那一行里的路径是脚本实际改过的配置文件。

### 安装指定版本

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/v2.2.2/install-as-nvm.sh | bash
```

## ✨ 核心特性

- ⚡ **性能巅峰**: 核心逻辑由 Zig 编写，版本解析瞬间完成。
- 🍎 **Apple Silicon 友好**: 自动检测架构，支持 Node.js 旧版本的 Rosetta 自动回退。
- 🐧 **Unix 原生**: 深度适配 macOS 和 Linux。
- 🔄 **自动切换**: 进入包含 `.nvmrc` 的目录时自动切换 Node 版本。
- 📦 **按版本隔离的全局包**: 与 nvm 一样，全局 npm 包留在各自的 Node 版本里。

## 🛠 使用方法

```bash
# 安装。`node` 是最新正式版，`lts/*` 是最新 LTS。
nvm install 22
nvm install --lts
nvm install             # 读取 .nvmrc 并安装，然后切换过去

# 切换。不带版本时从当前目录或父目录的 .nvmrc 读取。
nvm use 20
nvm use
nvm use --lts

nvm current
nvm which 20
nvm ls                  # -> 表示当前版本，并列出别名
nvm ls-remote --lts

nvm alias default 20    # 与 nvm default 20 相同
nvm run 20 --version
nvm exec 20 npm test
nvm uninstall 20
```

在终端里不带参数运行 `nvm` 会打开交互引导。`nvm guide` 和 `nvm interactive` 是同一个菜单。没有终端时，`nvm` 只打印一句说明并退出。同一个菜单可以改包的源：多个 `@scope` 同时指向不同仓库，默认源单独设置，然后同步到 npm、yarn、pnpm 和 bun。

```bash
nvm registry add @company https://npm.company.example
nvm registry china          # 默认源改为 https://registry.npmmirror.com，scope 保留
nvm registry official       # 默认源改为 https://registry.npmjs.org，scope 保留
nvm registry show
```

映射保存在 `$NVM_DIR/registries.json`。同步会改写 `~/.npmrc`、`~/.yarnrc`、`~/.yarnrc.yml`、pnpm 的 rc（Linux 是 `~/.config/pnpm/rc`，macOS 是 `~/Library/Preferences/pnpm/rc`）和 `~/.bunfig.toml` 里的默认源和 `@scope` 源。这些文件里的其他行会留下。`~/.yarnrc.yml` 里的 `npmScopes` 段会按已保存的 scope 重写。Electron 和其他二进制镜像不在这个命令里。

版本目录与 nvm 相同：`$NVM_DIR/versions/node`（默认 `~/.nvm`），已经装好的版本可以直接用。0.12 之前的 Node 从 `$NVM_DIR/vX.Y.Z` 读取。

默认下载镜像是 `https://npmmirror.com/mirrors/node`。要换镜像，设置 `NVM_NODEJS_ORG_MIRROR`。

`nvm version` 打印当前 Node 版本（这个 nvm 没有提供 Node 时是 `none` 或 `system`）。`nvm --version` 打印已安装工具的版本。

没有 `nvm completion` 命令，安装脚本也不会加入 shell 补全。

进入目录时会根据 `.nvmrc` 切换已安装的版本，找不到 `.nvmrc` 时再读 `.node-version`，都不会自动下载。全局包跟 nvm 一样放在各个 Node 版本里；`reinstall-packages` 和 `--reinstall-packages-from` 会把它们复制到要切换到的版本。

不做源码编译（`-s`，只安装官方二进制）、io.js / `unstable`（已停止维护，不在 Node 镜像上）和 `set-colors`（只影响终端颜色）。`nvm ls` 输出纯文本。

## ⚙️ Shell 配置

`install-as-nvm.sh` 会把下面几行追加到它更新的 shell 配置（`~/.bashrc`、`~/.zshrc` 或 `~/.profile`）：

```bash
# nvm: shell setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

新开一个终端，或 `source` 那个配置文件。之后的命令是 `nvm`。版本在 `$NVM_DIR/versions/node`。

## 📊 性能对比

下面是 **2026-10-22 15:38:50Z–15:40:25Z** 同一次运行里的暖启动和冷启动中位数，脚本是 [`benchmarks/measure.py`](benchmarks/measure.py)。环境：4 核 KVM 虚拟机，lscpu 型号为 `Intel(R) Xeon(R) Processor`，Ubuntu 24.04.5。znvm 是 ReleaseSafe，3,910,296 字节（3.73 MiB，未 strip）。对照 nvm v0.40.3（`nvm.sh` 150,227 字节）和 fnm 1.39.0（7,374,576 字节）。已安装 v22.14.0（默认）和 v20.19.0。PATH 只有工具目录加 `/usr/bin:/bin`。原始样本：[`benchmarks/results/2026-10-22-cold-warm.json`](benchmarks/results/2026-10-22-cold-warm.json)。

shell 启动是新的 `bash --noprofile --norc` 执行文档化 init，再减去同样方式测得的 `bash -c true`。暖：预热 5 次、采样 20 次，页缓存保持热（基线中位数 0.63 ms）。冷：20 次，不丢弃预热，每次包括基线都先 `sync` 并丢掉页缓存（基线中位数 2.02 ms，p95 3.91 ms）。每个冷样本序号里三个工具轮流测。fnm 的文档化 init 当时已经是 Node v22.14.0。暖运行里多一次 `fnm use` 是 2.50 ms（p95 2.80 ms），不是表中的数字。以这次的样本量，插值 p50 等于中位数。

| 管理器 | 暖中位数 | 暖 p95 | 冷中位数 | 冷 p95 |
| :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 115 ms | 121 ms | 128 ms |
| `fnm` | 1.58 ms | 1.76 ms | 4.70 ms | 6.67 ms |
| **`znvm`** | **3.31 ms** | **3.64 ms** | **5.01 ms** | **9.28 ms** |

下面的 `list` / `use` / `.nvmrc` 在已经初始化的 shell 里。暖：预热 10 次、采样 40 次，减去 shell 内 `true`（约 0.04 ms）。冷：20 次，每次命令前丢掉页缓存，shell 进程保留；减去该工具冷的 shell 内 `true`（0.20–0.26 ms）。`use` 在 v20.19.0 和 v22.14.0 之间交替。`.nvmrc` 的内容是 `20.19.0`。

| 管理器 | list 暖 | list 冷 | use 暖 | use 冷 | .nvmrc 暖 | .nvmrc 冷 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 559 ms | 557 ms | 158 ms | 221 ms | 166 ms | 222 ms |
| `fnm` | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms | 1.41 ms | 5.20 ms |
| **`znvm`** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** | **0.86 ms** | **3.06 ms** |

暖命令 p95：nvm 587 / 165 / 170 ms，fnm 1.63 / 1.70 / 1.87 ms，znvm 0.87 / 1.21 / 1.33 ms。冷命令 p95：nvm 570 / 246 / 244 ms，fnm 8.70 / 8.80 / 7.61 ms，znvm 5.03 / 7.36 / 4.69 ms（list / use / .nvmrc）。

这次暖、冷 shell 启动都是 fnm 低于 znvm，两者都低于 nvm。暖、冷的 shell 内命令都是 znvm 更低。znvm 冷启动的 p95（9.28 ms）比中位数散。

体积：znvm 3.73 MiB，fnm 7.03 MiB，nvm 146.7 KiB 脚本。

这次没有重跑安装。更早的 3 次安装（含下载）仍在 [`benchmarks/results/2026-10-22.json`](benchmarks/results/2026-10-22.json)：znvm 1241 ms，fnm 2317 ms，nvm 2327 ms。那个文件里的暖表和单次冷样本是更早的一次运行，上面的表替换它们。安装耗时主要是网络。

`benchmarks/benchmark_key_operations.sh` 已停用。它只采一次 `time`，只在 nvm 的计时里 `source nvm.sh`，并且调用了不存在的 `znvm resolve`。

## 📖 官方文档

完整文档请访问 [znvm.dev](https://znvm.dev) (即将上线！)。

## 🏗 本地开发

```bash
zig build -Doptimize=ReleaseSafe
```

## 📄 开源协议

MIT
