## 安装

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

## 为什么选择 znvm?

**znvm** = **Zig** + **nvm**。名字说明一切。

厌倦了缓慢的 **node version manager** 工具？**znvm** 专为追求速度与简洁的开发者设计：

- **⚡️ 瞬时响应**: 启动 < 5ms (对比 nvm 的 150ms+ 或 fnm 的 20ms)
- **🎯 Unix 优先**: 精简专注，无跨平台臃肿代码
- **🛠 零配置**: 直接使用现有的 `.nvmrc`

## 性能对比

**在 Apple M4 (16GB 内存, macOS 25.3) 上的真实基准**：

| 管理器 | `list` | `use` | `.nvmrc` |
| :--- | :--- | :--- | :--- |
| `nvm` | 708ms | 192ms | 189ms |
| `fnm` | 6ms | 4ms | 10ms |
| **`znvm`** | **4ms** | **3ms** | **2ms** |

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
