## Install

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

## Why znvm?

**znvm** = **Zig** + **nvm**. The name says it all.

Tired of slow **node version manager** tools? **znvm** is designed for developers who demand speed and simplicity:

- **⚡️ Measured startup**: 3.55 ms shell overhead on 2026-10-22 (nvm 118 ms, fnm's documented init 1.58 ms)
- **🎯 Unix-First**: Lean and focused, no cross-platform bloat
- **🛠 Zero Configuration**: Works with your existing `.nvmrc`

## Performance Comparison

**Warm medians, 2026-10-22, 4-vCPU KVM guest (Intel Xeon, Ubuntu 24.04), `benchmarks/measure.py`, znvm ReleaseSafe.** In-shell commands are 40 samples after 10 warmup. Shell startup is 20 samples after 5 warmup. fnm's documented init already had Node v22.14.0 active. Full samples: `benchmarks/results/2026-10-22.json`.

| Manager | Shell startup | `list` | `use` | `.nvmrc` | Size |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 118 ms | 527 ms | 153 ms | 166 ms | 146.7 KiB script |
| `fnm` | 1.58 ms | 1.31 ms | 1.46 ms | 1.43 ms | 7.03 MiB |
| **`znvm`** | **3.55 ms** | **0.62 ms** | **0.89 ms** | **0.97 ms** | **3.73 MiB** |

Installing Node 22.13.1 from nodejs.org (cache cleared, download included, 3 samples): znvm 1241 ms, fnm 2317 ms, nvm 2327 ms. That gap is mostly network. Cold single samples are in the JSON, not in this table. znvm's shell startup on this run was lower than nvm and higher than fnm.

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
