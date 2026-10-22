# znvm (Zig Node Version Manager)

[简体中文](./README_zh.md)

**A Node.js version manager built with Zig. Everyday commands follow nvm, versions live in `~/.nvm`, and downloads default to npmmirror.**

[![GitHub stars](https://img.shields.io/github/stars/charlzyx/znvm.svg?style=social)](https://github.com/charlzyx/znvm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Language: Zig](https://img.shields.io/badge/Language-Zig-f7a41d.svg)](https://ziglang.org/)

---

## 🚀 Why znvm?

**znvm** is a Zig Node.js version manager for everyday nvm use. The default download mirror is npmmirror. The Benchmarks section is a measured comparison, not a slogan.

- **Measured startup**: On 2026-10-22, warm shell startup was **3.31 ms** for znvm, **1.58 ms** for fnm, and **113 ms** for nvm. After dropping the page cache on every sample, those medians were **5.01 ms**, **4.70 ms**, and **121 ms**. See Benchmarks for p95 and the in-shell commands.
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

`install-as-nvm.sh` installs znvm and makes the `nvm` command run it, including the `~/.nvm/nvm.sh` file existing shell configs already source. Running it again is safe: it will not duplicate shell config, and it will not delete Node versions already installed under `~/.nvm/versions/node`. znvm uses that same tree.

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
- 📦 **Per-version globals**: Global npm packages stay inside each Node version, as they do with nvm. Set `ZNVM_NPM_PREFIX` to an absolute path for one shared prefix.
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

Node versions live in `$NVM_DIR/versions/node` (default `~/.nvm`), including versions nvm already installed. `ZNVM_DIR` is only used when `NVM_DIR` is unset. A previous znvm tree at `~/.znvm/versions/vX.Y.Z` is still detected. Node older than 0.12 is read from `$NVM_DIR/vX.Y.Z`, matching nvm.

The download mirror defaults to `https://npmmirror.com/mirrors/node`. Override it with `ZNVM_NODE_MIRROR` or `NVM_NODEJS_ORG_MIRROR`.

`znvm version` with no arguments prints the znvm version. `nvm version` prints the active Node version (`none` or `system` when znvm is not providing it). `nvm --version` and `znvm --version` both print the znvm version.

Shell setup switches to `.nvmrc` when you enter a directory, then the default alias. It does not download a missing version. `.node-version` is used only when no `.nvmrc` exists anywhere above the current directory (nvm 0.40 reads `.nvmrc` only). `#` comments are ignored.

Global npm packages stay inside each Node version, as they do with nvm. `reinstall-packages` and `--reinstall-packages-from` copy them to the version you are switching to. Set `ZNVM_NPM_PREFIX` to an absolute path when you want one shared global prefix instead.

Not implemented, because they are not just a different default:

- `-s` compiles Node from source. znvm installs official binaries only.
- io.js and the `unstable` alias are retired and are not on the Node mirror.
- `set-colors` only changes nvm.sh's terminal colors. znvm prints plain text.

## ⚙️ Shell Setup

To start using `znvm`, add the following to your shell configuration file (e.g., `~/.zshrc`, `~/.bashrc`):

```bash
# Initialize znvm
eval "$(znvm env)"
```

> **Note**: The installation script attempts to configure this automatically. If `znvm` command is not found, ensure the binary is in your `PATH`.

## 📊 Benchmarks

Paired warm and cold medians from [`benchmarks/measure.py`](benchmarks/measure.py), **2026-10-22 15:38:50Z–15:40:25Z**. Hardware: 4-vCPU KVM guest, Intel Xeon (lscpu model name `Intel(R) Xeon(R) Processor`), Ubuntu 24.04.5. znvm was ReleaseSafe, 3,910,296 bytes (3.73 MiB, not stripped). Compared with nvm v0.40.3 (`nvm.sh` 150,227 bytes) and fnm 1.39.0 (7,374,576 bytes). Installed versions: v22.14.0 (default) and v20.19.0. PATH was the tool directory plus `/usr/bin:/bin`. Raw samples: [`benchmarks/results/2026-10-22-cold-warm.json`](benchmarks/results/2026-10-22-cold-warm.json).

Shell startup is a fresh `bash --noprofile --norc` running the documented init, minus `bash -c true` measured the same way. Warm: 5 warmup, 20 samples, page cache left hot (baseline median 0.63 ms). Cold: 20 samples, no discarded warmup, `sync` and a page-cache drop before every sample including the baseline (baseline median 2.02 ms, p95 3.91 ms). Tools are round-robin inside each cold sample index. fnm's documented init already had Node v22.14.0. An extra warm `fnm use` was 2.50 ms (p95 2.80 ms) and is not the headline. At these sample counts the interpolated p50 equals the median.

| Manager | Warm median | Warm p95 | Cold median | Cold p95 |
| :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 115 ms | 121 ms | 128 ms |
| `fnm` | 1.58 ms | 1.76 ms | 4.70 ms | 6.67 ms |
| **`znvm`** | **3.31 ms** | **3.64 ms** | **5.01 ms** | **9.28 ms** |

`list` / `use` / `.nvmrc` below are inside an already-initialized shell. Warm: 10 warmup, 40 samples, minus an in-shell `true` (about 0.04 ms). Cold: 20 samples, page cache dropped before each command, shell process kept; adjusted by that tool's cold in-shell `true` (0.20–0.26 ms). `use` alternates v20.19.0 and v22.14.0. `.nvmrc` contains `20.19.0`.

| Manager | list warm | list cold | use warm | use cold | .nvmrc warm | .nvmrc cold |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 559 ms | 557 ms | 158 ms | 221 ms | 166 ms | 222 ms |
| `fnm` | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms | 1.41 ms | 5.20 ms |
| **`znvm`** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** | **0.86 ms** | **3.06 ms** |

Warm command p95: nvm 587 / 165 / 170 ms, fnm 1.63 / 1.70 / 1.87 ms, znvm 0.87 / 1.21 / 1.33 ms. Cold command p95: nvm 570 / 246 / 244 ms, fnm 8.70 / 8.80 / 7.61 ms, znvm 5.03 / 7.36 / 4.69 ms (list / use / .nvmrc).

On this run, warm and cold shell startup were lower for fnm than for znvm, and both were lower than nvm. Warm and cold in-shell commands were lower for znvm. znvm's cold startup p95 (9.28 ms) is wider than its median.

Sizes: znvm 3.73 MiB, fnm 7.03 MiB, nvm 146.7 KiB script.

Installing Node v22.13.1 was not repeated in this run. The earlier 3-sample timing, with the download included, is still in [`benchmarks/results/2026-10-22.json`](benchmarks/results/2026-10-22.json): znvm 1241 ms, fnm 2317 ms, nvm 2327 ms. That file's warm table and single cold sample are an earlier run; the tables above replace them. Network time dominated the install.

`benchmarks/benchmark_key_operations.sh` is retired. It took one `time` sample, included `source nvm.sh` only in the nvm timings, and called `znvm resolve`, which is not a command.

## 📖 Documentation

Full documentation is available at [znvm.dev](https://znvm.dev).

## 🏗 Development

```bash
zig build -Doptimize=ReleaseSafe
```

## 📄 License

MIT
