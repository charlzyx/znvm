## 安装

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

## 为什么选择 znvm?

**znvm** = **Zig** + **nvm**。名字说明一切。

厌倦了缓慢的 **node version manager** 工具？**znvm** 专为追求速度与简洁的开发者设计：

- **⚡️ 实测启动**: 2026-10-22 的 shell 开销 3.55 ms（nvm 118 ms，fnm 文档化 init 1.58 ms）
- **🎯 Unix 优先**: 精简专注，无跨平台臃肿代码
- **🛠 零配置**: 直接使用现有的 `.nvmrc`

## 性能对比

**2026-10-22 暖机中位数。4 核 KVM 虚拟机（Intel Xeon，Ubuntu 24.04），`benchmarks/measure.py`，znvm 为 ReleaseSafe。** shell 内命令预热 10 次、采样 40 次。shell 启动预热 5 次、采样 20 次。fnm 的文档化 init 当时已经激活 Node v22.14.0。完整样本：`benchmarks/results/2026-10-22.json`。

| 管理器 | shell 启动 | `list` | `use` | `.nvmrc` | 体积 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 118 ms | 527 ms | 153 ms | 166 ms | 146.7 KiB 脚本 |
| `fnm` | 1.58 ms | 1.31 ms | 1.46 ms | 1.43 ms | 7.03 MiB |
| **`znvm`** | **3.55 ms** | **0.62 ms** | **0.89 ms** | **0.97 ms** | **3.73 MiB** |

从 nodejs.org 安装 Node 22.13.1（清缓存，含下载，3 次）：znvm 1241 ms，fnm 2317 ms，nvm 2327 ms。差距主要来自网络。冷启动单次样本只在 JSON 里。这次 znvm 的 shell 启动低于 nvm、高于 fnm。

## 是什么让 znvm 与众不同？

### 🚀 **Zig 驱动的极速**
基于 Zig 的零成本抽象和显式内存控制构建。无运行时开销，无垃圾回收停顿。

### 🧘 **Unix 哲学**
做一件事，并做好它。znvm 专注于 macOS 和 Linux，利用原生系统调用，而非跨平台妥协。

### 📦 **零依赖**
单个静态二进制文件。无运行时，无包管理器依赖，无意外。

### 🔌 **即插即用**
与您现有的 `.nvmrc` 文件和 shell 工作流无缝协作。迁移轻松无负担。

## 关键词

znvm, nvm, fnm, nvm-slow, node version manager, node-version-manage, zig, fast, lightweight, unix, zero-overhead, 快速, 轻量, Unix, Node.js 版本管理器, 零负担
