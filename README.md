# znvm (Zig Node Version Manager)

[简体中文](./README_zh.md)

**A Node.js version manager built with Zig. Everyday commands follow nvm, versions live in `~/.nvm`, and downloads default to npmmirror.**

[![GitHub stars](https://img.shields.io/github/stars/charlzyx/znvm.svg?style=social)](https://github.com/charlzyx/znvm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Language: Zig](https://img.shields.io/badge/Language-Zig-f7a41d.svg)](https://ziglang.org/)

---

## 🚀 Why znvm?

**znvm** is a Zig Node.js version manager for everyday nvm use. The default download mirror is npmmirror. The Benchmarks section is a measured comparison, not a slogan.

- **Measured startup**: On 2026-10-22, a fresh bash running `eval "$(znvm env)"` added **3.55 ms** over `bash -c true`. The same setup was **118 ms** for nvm 0.40.3 and **1.58 ms** for fnm 1.39.0's documented init (Node was already active). In-shell `list` / `use` / `.nvmrc` medians were **0.62 / 0.89 / 0.97 ms**.
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

Warm medians from [`benchmarks/measure.py`](benchmarks/measure.py) on **2026-10-22**. Hardware: 4-vCPU KVM guest, Intel Xeon (lscpu model name `Intel(R) Xeon(R) Processor`), Ubuntu 24.04.5. The timed znvm binary was ReleaseSafe, 3,908,768 bytes (3.73 MiB, not stripped). Adding `--copy-packages-from` afterward rebuilds to 3,910,296 bytes, which is still 3.73 MiB at this precision. Those timings were not re-run. Compared with nvm v0.40.3 (`nvm.sh` 150,227 bytes) and fnm 1.39.0 (7,374,576 bytes). Installed versions: v22.14.0 (default) and v20.19.0. PATH was the tool directory plus `/usr/bin:/bin`. Raw samples: [`benchmarks/results/2026-10-22.json`](benchmarks/results/2026-10-22.json).

| Manager | Shell startup | `list` | `use` | `.nvmrc` | Size |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 118 ms | 527 ms | 153 ms | 166 ms | 146.7 KiB script |
| `fnm` | 1.58 ms | 1.31 ms | 1.46 ms | 1.43 ms | 7.03 MiB |
| **`znvm`** | **3.55 ms** | **0.62 ms** | **0.89 ms** | **0.97 ms** | **3.73 MiB** |

Shell startup is a fresh `bash --noprofile --norc` running the documented init, minus `bash -c true` (5 warmup, 20 samples). fnm's `eval "$(fnm env --use-on-cd)"` already resolved to Node v22.14.0 (`latency.fnm.node_after_documented_init` in the JSON), so 1.58 ms is the figure to compare. The JSON method text still says that init does not select a default; that sentence is stale. An extra `fnm use 22.14.0` after init was 2.43 ms and is not the headline.

`list` / `use` / `.nvmrc` are inside an already-initialized shell, minus an in-shell `true` (10 warmup, 40 samples). `use` alternates v20.19.0 and v22.14.0. `.nvmrc` contains `20.19.0`.

Installing Node v22.13.1 from `https://nodejs.org/dist` (tarball `node-v22.13.1-linux-x64.tar.xz`, 29,885,824 bytes, cache cleared each sample, 3 samples, download included). Raw medians: znvm 1241 ms, fnm 2317 ms, nvm 2327 ms. Network time dominates, so this is not a stable multiplier.

One sample after dropping the page cache is in the JSON under `cold`. It is not a median and is not the table above. The fnm cold startup command also ran `fnm use 22.14.0`.

`benchmarks/benchmark_key_operations.sh` is retired. It took one `time` sample, included `source nvm.sh` only in the nvm timings, and called `znvm resolve`, which is not a command.

## 📖 Documentation

Full documentation is available at [znvm.dev](https://znvm.dev).

## 🏗 Development

```bash
zig build -Doptimize=ReleaseSafe
```

## 📄 License

MIT
