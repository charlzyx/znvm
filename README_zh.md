# znvm (Zig Node Version Manager)

**极致轻量、零配置的 Node.js 版本管理器。基于 Zig 打造，专为性能与 Unix 系统优化。**

[![GitHub stars](https://img.shields.io/github/stars/charlzyx/znvm.svg?style=social)](https://github.com/charlzyx/znvm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Language: Zig](https://img.shields.io/badge/Language-Zig-f7a41d.svg)](https://ziglang.org/)

---

## 🚀 为什么选择 znvm?

传统的 Node.js 版本管理器要么太慢（基于 Shell），要么功能过于臃肿（基于 Rust/Go）。**znvm** 利用 **Zig** 的高性能，实现了极致的性能表现和零负担的运行体验。

- **瞬时响应**: 启动延迟 **< 5ms**。比 `nvm` 更快，甚至超越 `fnm`。
- **零配置**: 完美支持 `.nvmrc`。只需 `cd` 进入目录，环境立即就绪。
- **极简专注**: 无冗余依赖，无 Windows 平台的沉重抽象。纯粹为 Unix 性能而生。
- **智能架构**: Zig 核心处理复杂的 SemVer 解析；Shell 脚本负责环境切换。

## 📦 快速安装

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/main/install.sh | bash
```

### 当作 `nvm` 使用

`install-as-nvm.sh` 会安装 znvm，并让 `nvm` 命令以及已有配置里的 `~/.nvm/nvm.sh` 指向 znvm。脚本可以重复执行：不会重复写入 shell 配置，也不会删除 nvm 已经装在 `~/.nvm` 里的 Node。znvm 自己的版本放在 `~/.znvm`。

如果原来的 `nvm.sh` 和 `bash_completion` 还不是 znvm 的兼容文件，会先各备份一份为 `*.pre-znvm`。

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/main/install-as-nvm.sh | bash
```

新开一个终端，或 source 脚本打印出的配置文件。之后 `nvm install`、`nvm use`、`nvm ls` 等日常命令都会走 znvm。

## ✨ 核心特性

- ⚡ **性能巅峰**: 核心逻辑由 Zig 编写，版本解析瞬间完成。
- 🍎 **Apple Silicon 友好**: 自动检测架构，支持 Node.js 旧版本的 Rosetta 自动回退。
- 🐧 **Unix 原生**: 深度适配 macOS 和 Linux。
- 🔄 **自动切换**: 进入包含 `.nvmrc` 的目录时自动切换 Node 版本。
- 📦 **共享全局包**: 切换 Node.js 版本后，已安装的全局 npm 包仍然可用。

## 🛠 使用方法

```bash
znvm install 22          # 安装该版本线的最新版本
znvm install --lts       # 最新 LTS
znvm install             # 读取 .nvmrc 并安装，然后切换过去

znvm use 20
znvm use                 # 从当前目录或父目录的 .nvmrc 切换
znvm current
znvm which 20
znvm ls                  # -> 表示当前版本，并列出别名
znvm ls-remote --lts

znvm alias default 20    # 与 znvm default 20 相同
znvm run 20 --version
znvm exec 20 npm test
znvm uninstall 20
```

安装 `install-as-nvm.sh` 之后，这些命令也可以用 `nvm` 调用。

和 nvm 的有意差异：版本数据在 `~/.znvm` 而不是 `~/.nvm`；默认下载镜像是 npmmirror（可用 `ZNVM_NODE_MIRROR` 或 `NVM_NODEJS_ORG_MIRROR` 覆盖）；只读取 `.nvmrc`（向上查找，支持 `#` 注释），不读取 `.node-version`；进入目录时会自动切换已安装的版本，但不会自动下载；全局 npm 包在各 Node 版本之间共享。不支持源码编译、io.js 和 `reinstall-packages`。`znvm version` 不带参数时打印 znvm 自身版本，`nvm version` 打印当前 Node 版本。

## ⚙️ Shell 配置

要开始使用 `znvm`，请将以下内容添加到您的 Shell 配置文件（如 `~/.zshrc`, `~/.bashrc`）中：

```bash
# 初始化 znvm
eval "$(znvm env)"
```

> **注意**：安装脚本通常会自动为您配置。如果 `znvm` 命令未找到，请确保二进制文件位于您的 `PATH` 中。

## 📊 性能对比

| 管理器 | 开发语言 | 启动延迟 |
| :--- | :--- | :--- |
| `nvm` | Bash | ~150ms+ |
| `fnm` | Rust | ~20ms |
| **`znvm`** | **Zig** | **< 5ms** |

## 📖 官方文档

完整文档请访问 [znvm.dev](https://znvm.dev) (即将上线！)。

## 🏗 本地开发

```bash
zig build -Doptimize=ReleaseSafe
```

## 📄 开源协议

MIT
