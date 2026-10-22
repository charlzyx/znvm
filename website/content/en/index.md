## Install

```bash
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

## Why znvm?

**znvm** = **Zig** + **nvm**. The name says it all.

Tired of slow **node version manager** tools? **znvm** is designed for developers who demand speed and simplicity:

- **⚡️ Measured startup**: warm 3.31 ms, cold 5.01 ms on 2026-10-22 (fnm 1.58 / 4.70 ms, nvm 113 / 121 ms)
- **🎯 Unix-First**: Lean and focused, no cross-platform bloat
- **🛠 Zero Configuration**: Works with your existing `.nvmrc`

## Performance Comparison

**One run, 2026-10-22 15:38–15:40 UTC, 4-vCPU KVM guest (Intel Xeon, Ubuntu 24.04), `benchmarks/measure.py`, znvm ReleaseSafe.** Warm shell startup is 20 samples after 5 warmup. Cold shell startup is 20 samples with the page cache dropped each time. Command samples: warm 40 after 10 warmup; cold 20 in an already-open shell. p50 equals the median here. Samples: `benchmarks/results/2026-10-22-cold-warm.json`.

| Manager | Warm startup | Cold startup | list warm | list cold | use warm | use cold | .nvmrc warm | .nvmrc cold |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 121 ms | 559 ms | 557 ms | 158 ms | 221 ms | 166 ms | 222 ms |
| `fnm` | 1.58 ms | 4.70 ms | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms | 1.41 ms | 5.20 ms |
| **`znvm`** | **3.31 ms** | **5.01 ms** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** | **0.86 ms** | **3.06 ms** |

Shell-startup p95: nvm 115 / 128 ms, fnm 1.76 / 6.67 ms, znvm 3.64 / 9.28 ms (warm / cold). fnm's documented init already had Node v22.14.0. On this run, shell startup was lower for fnm than znvm; in-shell commands were lower for znvm. The earlier install timing (3 samples, download included: znvm 1241 ms, fnm 2317 ms, nvm 2327 ms) is in `benchmarks/results/2026-10-22.json` and was not repeated.

## What Makes znvm Different?

### 🚀 **Zig-Powered Speed**
Built with Zig's zero-cost abstractions and explicit memory control. No runtime overhead, no garbage collection pauses.

### 🧘 **Unix Philosophy**
Do one thing and do it well. znvm focuses exclusively on macOS and Linux, leveraging native system calls instead of cross-platform compromises.

### 📦 **Zero Dependencies**
Single static binary. No runtime, no package manager dependencies, no surprises.

### 🔌 **Drop-in `nvm`**
The install command above gives you `nvm`. Versions live in `~/.nvm` (`NVM_DIR`). An interactive guided mode is planned; today you use the `nvm` command line.

## Keywords

znvm, nvm, fnm, nvm-slow, node version manager, node-version-manage, zig, fast, lightweight, unix, zero-overhead
