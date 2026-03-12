## Install

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

## Why znvm?

**znvm** = **Zig** + **nvm**. The name says it all.

Tired of slow **node version manager** tools? **znvm** is designed for developers who demand speed and simplicity:

- **⚡️ Instant Performance**: Starts in < 5ms (vs nvm's 150ms+ or fnm's 20ms)
- **🎯 Unix-First**: Lean and focused, no cross-platform bloat
- **🛠 Zero Configuration**: Works with your existing `.nvmrc`

## Performance Comparison

**Actual benchmark on Apple M4 (16GB RAM, macOS 25.3)**:

| Manager | `list` | `use` | `.nvmrc` |
| :--- | :--- | :--- | :--- |
| `nvm` | 708ms | 192ms | 189ms |
| `fnm` | 6ms | 4ms | 10ms |
| **`znvm`** | **4ms** | **3ms** | **2ms** |

## What Makes znvm Different?

### 🚀 **Zig-Powered Speed**
Built with Zig's zero-cost abstractions and explicit memory control. No runtime overhead, no garbage collection pauses.

### 🧘 **Unix Philosophy**
Do one thing and do it well. znvm focuses exclusively on macOS and Linux, leveraging native system calls instead of cross-platform compromises.

### 📦 **Zero Dependencies**
Single static binary. No runtime, no package manager dependencies, no surprises.

### 🔌 **Drop-in Replacement**
Works seamlessly with your existing `.nvmrc` files and shell workflows. Migration is effortless.

## Keywords

znvm, nvm, fnm, nvm-slow, node version manager, node-version-manage, zig, fast, lightweight, unix, zero-overhead
