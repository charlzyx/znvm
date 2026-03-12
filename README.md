# znvm (Zig Node Version Manager)

[简体中文](./README_zh.md)

**The blazingly fast, zero-config Node.js version manager. Built with Zig for performance. Optimized for Unix.**

[![GitHub stars](https://img.shields.io/github/stars/charlzyx/znvm.svg?style=social)](https://github.com/charlzyx/znvm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Language: Zig](https://img.shields.io/badge/Language-Zig-f7a41d.svg)](https://ziglang.org/)

---

## 🚀 Why znvm?

Traditional Node.js version managers are either slow (written in Shell) or feature-bloated (written in Rust/Go). **znvm** leverages **Zig** to achieve extreme performance with zero overhead.

- **Instant Speed**: Startup latency **< 5ms**. Faster than `nvm` and even `fnm`.
- **Zero Configuration**: Perfect support for `.nvmrc`. Just `cd` and you're ready.
- **Minimal & Focused**: No bloated dependencies, no Windows overhead. Just pure Unix performance.
- **Smart Architecture**: Zig handles complex SemVer parsing; Shell handles env switching.

## 📦 Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/main/install.sh | bash
```

### Install Specific Version

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/v2.0.0/install.sh | bash
```

## ✨ Core Features

- ⚡ **Instant Performance**: Core logic written in Zig for lightning-fast resolution.
- 🍎 **Apple Silicon Friendly**: Automatic architecture detection and Rosetta fallback.
- 🐧 **Unix-First**: Native support for macOS and Linux.
- 🔄 **Auto Switch**: Automatic version switching when entering a directory with `.nvmrc`.
- 📦 **Isolated Environments**: Per-version isolation for global packages, npm cache, and Corepack.
- ⭐ **Default Version**: Set a default version to use when no `.nvmrc` is present.

## 🛠 Usage

```bash
# Install a version
znvm install 22          # Match latest v22.x.x

# Switch version
znvm use 20              # Use Node 20
znvm use                 # Automatically use version from .nvmrc

# List installed versions
znvm ls                  # Shows [*] for current, [->] for default

# Set default version
znvm default 20          # Set v20 as default
znvm default             # Show current default

# Uninstall
znvm uninstall 20
```

## ⚙️ Shell Setup

To start using `znvm`, add the following to your shell configuration file (e.g., `~/.zshrc`, `~/.bashrc`):

```bash
# Initialize znvm
eval "$(znvm env)"
```

> **Note**: The installation script attempts to configure this automatically. If `znvm` command is not found, ensure the binary is in your `PATH`.

## 📊 Benchmarks

| Manager | Language | Startup Latency |
| :--- | :--- | :--- |
| `nvm` | Bash | ~150ms+ |
| `fnm` | Rust | ~20ms |
| **`znvm`** | **Zig** | **< 5ms** |

## 📖 Documentation

Full documentation is available at [znvm.dev](https://znvm.dev).

## 🏗 Development

```bash
zig build -Doptimize=ReleaseSafe
```

## 📄 License

MIT
