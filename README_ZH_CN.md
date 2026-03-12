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

## ✨ 核心特性

- ⚡ **性能巅峰**: 核心逻辑由 Zig 编写，版本解析瞬间完成。
- 🍎 **Apple Silicon 友好**: 自动检测架构，支持 Node.js 旧版本的 Rosetta 自动回退。
- 🐧 **Unix 原生**: 深度适配 macOS 和 Linux。
- 🔄 **自动切换**: 进入包含 `.nvmrc` 的目录时自动切换 Node 版本。
- 📦 **隔离环境**: 每个 Node 版本拥有独立的全局包、npm 缓存及 Corepack 环境。

## 🛠 使用方法

```bash
# 安装版本
nv install 22          # 自动匹配并安装最新的 v22.x.x

# 切换版本
nv use 20              # 使用 Node 20
nv use                 # 自动从 .nvmrc 读取版本并切换

# 列出已安装版本
nv ls

# 设置默认版本
nv default 22

# 卸载版本
nv rm 20
```
*注：建议将 `znvm` 设为别名 `nv` 以获得最佳体验。*

## 📊 性能对比

| 管理器 | 开发语言 | 启动延迟 |
| :--- | :--- | :--- |
| `nvm` | Bash | ~150ms+ |
| `fnm` | Rust | ~20ms |
| **`znvm`** | **Zig** | **< 5ms** |

## 📖 官方文档

完整文档请访问 [znvm.sh](https://znvm.sh) (即将上线！)。

## 🏗 本地开发

```bash
zig build -Doptimize=ReleaseSafe
```

## 📄 开源协议

MIT
