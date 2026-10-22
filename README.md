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
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/v2.2.2/install.sh | bash
```

### Use it as `nvm`

`install-as-nvm.sh` installs znvm and makes the `nvm` command run it, including the `~/.nvm/nvm.sh` file existing shell configs already source. Running it again is safe: it will not duplicate shell config, and it will not delete Node versions already installed by nvm. Those stay in `~/.nvm`. znvm keeps its own copies in `~/.znvm`.

The previous `nvm.sh` and `bash_completion`, if they were not already znvm shims, are copied once to `nvm.sh.pre-znvm` and `bash_completion.pre-znvm`.

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/main/install-as-nvm.sh | bash
```

Open a new terminal, or `source` the printed profile. `nvm install`, `nvm use`, `nvm ls`, and the other commands below then run znvm. `eval "$(znvm env)"` also defines an `nvm` function.

## ✨ Core Features

- ⚡ **Instant Performance**: Core logic written in Zig for lightning-fast resolution.
- 🍎 **Apple Silicon Friendly**: Automatic architecture detection and Rosetta fallback.
- 🐧 **Unix-First**: Native support for macOS and Linux.
- 🔄 **Auto Switch**: Automatic version switching when entering a directory with `.nvmrc`.
- 📦 **Shared Global Packages**: Global npm packages remain available when switching Node.js versions.
- ⭐ **Default Version**: Set a default version to use when no `.nvmrc` is present.

## 🛠 Usage

```bash
# Install a version. `node` is the newest release, `lts/*` the newest LTS.
znvm install 22
znvm install --lts
znvm install          # version from .nvmrc, then switch to it

# Switch version. `use` with no version reads .nvmrc from this directory or a parent.
znvm use 20
znvm use
znvm use --lts

# What is active, and where is its node binary?
znvm current
znvm which 20

# List installed versions (`->` marks the active one) and aliases
znvm ls
znvm ls 20
znvm ls-remote --lts

# Default and other aliases. `default` is the same as `alias default`.
znvm alias default 20
znvm alias
znvm unalias work

# Run one command without changing the shell
znvm run 20 --version
znvm exec 20 npm test

# Remove a version, or drop it from PATH
znvm uninstall 20
znvm deactivate
```

`nvm <command>` accepts the same commands after `install-as-nvm.sh` (or after `eval "$(znvm env)"`).

### Differences from nvm

- Node versions installed by znvm live in `~/.znvm`, not `~/.nvm`. `install-as-nvm.sh` does not migrate or delete an existing nvm install.
- The download mirror defaults to `https://npmmirror.com/mirrors/node`. Override it with `ZNVM_NODE_MIRROR` or `NVM_NODEJS_ORG_MIRROR`.
- `znvm version` with no arguments prints the znvm version. `nvm version` prints the active Node version (`none` or `system` when znvm is not providing it). `nvm --version` and `znvm --version` both print the znvm version.
- Shell setup switches versions when you enter a directory with `.nvmrc`, and falls back to the default alias. It does not install a missing version; run `install` for that.
- Only `.nvmrc` is read. The search walks parent directories, `#` comments are ignored, and `.node-version` is not consulted.
- Global npm packages are shared across Node versions. Source builds (`-s`), io.js, and `reinstall-packages` are not supported.

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
