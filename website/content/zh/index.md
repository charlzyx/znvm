## 安装

```bash
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

## 为什么选择 znvm?

**znvm** = **Zig** + **nvm**。名字说明一切。

厌倦了缓慢的 **node version manager** 工具？**znvm** 专为追求速度与简洁的开发者设计：

- **⚡️ 实测启动**: 2026-10-22 暖 3.31 ms、冷 5.01 ms（fnm 1.58 / 4.70 ms，nvm 113 / 121 ms）
- **🎯 Unix 优先**: 精简专注，无跨平台臃肿代码
- **🛠 零配置**: 直接使用现有的 `.nvmrc`

## 性能对比

**同一次运行，2026-10-22 15:38–15:40 UTC。4 核 KVM 虚拟机（Intel Xeon，Ubuntu 24.04），`benchmarks/measure.py`，znvm 为 ReleaseSafe。** 暖 shell 启动预热 5 次、采样 20 次。冷 shell 启动 20 次，每次丢掉页缓存。命令：暖为预热 10 次、采样 40 次；冷为已打开的 shell 里 20 次。这里 p50 等于中位数。样本：`benchmarks/results/2026-10-22-cold-warm.json`。

| 管理器 | 暖启动 | 冷启动 | list 暖 | list 冷 | use 暖 | use 冷 | .nvmrc 暖 | .nvmrc 冷 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 121 ms | 559 ms | 557 ms | 158 ms | 221 ms | 166 ms | 222 ms |
| `fnm` | 1.58 ms | 4.70 ms | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms | 1.41 ms | 5.20 ms |
| **`znvm`** | **3.31 ms** | **5.01 ms** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** | **0.86 ms** | **3.06 ms** |

shell 启动 p95：nvm 115 / 128 ms，fnm 1.76 / 6.67 ms，znvm 3.64 / 9.28 ms（暖 / 冷）。fnm 的文档化 init 当时已经激活 Node v22.14.0。这次 shell 启动是 fnm 低于 znvm；shell 内命令是 znvm 更低。更早的安装计时（含下载，3 次：znvm 1241 ms，fnm 2317 ms，nvm 2327 ms）在 `benchmarks/results/2026-10-22.json`，这次没有重跑。

## 是什么让 znvm 与众不同？

### 🚀 **Zig 驱动的极速**
基于 Zig 的零成本抽象和显式内存控制构建。无运行时开销，无垃圾回收停顿。

### 🧘 **Unix 哲学**
做一件事，并做好它。znvm 专注于 macOS 和 Linux，利用原生系统调用，而非跨平台妥协。

### 📦 **零依赖**
单个静态二进制文件。无运行时，无包管理器依赖，无意外。

### 🔌 **当作 `nvm` 使用**
上面的安装命令提供的是 `nvm`。版本放在 `~/.nvm`（`NVM_DIR`）。交互式引导模式还在计划中；现在使用 `nvm` 命令行。

## 关键词

znvm, nvm, fnm, nvm-slow, node version manager, node-version-manage, zig, fast, lightweight, unix, zero-overhead, 快速, 轻量, Unix, Node.js 版本管理器, 零负担
