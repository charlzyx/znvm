# Get Started

**znvm** — **Zero-overhead Node Version Manager**

A **Node.js version manager** built with Zig. After install, the command is `nvm`. Versions live in `$NVM_DIR/versions/node` (default `~/.nvm`). The default download mirror is npmmirror. On 2026-10-22, warm shell startup was **3.31 ms** and cold shell startup was **5.01 ms** (see the homepage tables).

In a terminal, `nvm` with no arguments opens an interactive guide (`nvm guide` does the same). Without a terminal, it prints a short notice and exits.

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

When it finishes, it prints:

```text
nvm is ready.

Open a new terminal, or run:
  source "~/.bashrc"

export NVM_DIR="$HOME/.nvm"
nvm install 22
nvm use 22
nvm ls

Node versions are stored in $NVM_DIR/versions/node.
Downloads use https://npmmirror.com/mirrors/node unless NVM_NODEJS_ORG_MIRROR is set.
```

The `source` path is the profile the script actually updated (`~/.bashrc`, `~/.zshrc`, or `~/.profile`). Running the script again is safe: it does not duplicate that block, and it does not delete Node versions already under `~/.nvm/versions/node`.

### What the installer does

1. Detects your platform (macOS/Linux) and architecture (x64/arm64)
2. Installs the `nvm` command and writes `~/.nvm/nvm.sh`
3. Appends the `NVM_DIR` startup lines to your shell profile
4. Leaves existing Node versions in `$NVM_DIR/versions/node` in place

### Shell setup

The installer writes:

```bash
# nvm: shell setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

Open a new terminal, or `source` that profile. The command after that is `nvm`.

## Interactive guide

```bash
nvm
```

The menu uses number keys and Enter. It installs, switches, lists, and uninstalls by running the same `nvm` commands as the sections below. Chinese prompts are used when `LC_ALL`, `LC_MESSAGES`, or `LANG` starts with `zh`.

## Registries

`nvm registry` keeps one default registry and any number of `@scope` routes, then writes them for npm, yarn, pnpm, and bun. The interactive menu can view that map, add or edit a scope, delete one, set the default, sync every file, switch to the China default while keeping scopes, or restore the official npm registry.

```bash
nvm registry add @company https://npm.company.example
nvm registry china
nvm registry show
```

`china` sets the default to `https://registry.npmmirror.com`. `official` sets it to `https://registry.npmjs.org`. Scope routes stay in place either way. The map is stored in `$NVM_DIR/registries.json`. Sync updates `~/.npmrc`, `~/.yarnrc`, `~/.yarnrc.yml`, the pnpm rc, and `~/.bunfig.toml`. Other settings in those files stay. Electron and other binary mirrors are not changed.

## Usage

### Install Node.js

Use `22` to get the latest v22.x.x:

```bash
nvm install 22            # Latest v22.x.x
nvm install --lts         # Latest LTS
nvm install 20.11.0       # Specific version
nvm install v18.20.0      # With v prefix
nvm install               # Version from .nvmrc, then switch to it
```

### Switch Versions

```bash
nvm use 20                # Switch to Node 20
nvm use                   # Read .nvmrc from this directory or a parent
nvm use --lts
```

### List Installed Versions

```bash
nvm ls
nvm current
nvm which 20
```

`->` marks the active version. Aliases are listed after the versions.

### Set Default Version

```bash
nvm alias default 20      # Same as: nvm default 20
nvm alias
```

The default alias is used when you enter a directory that has no `.nvmrc` and no `.node-version`.

### Uninstall a Version

```bash
nvm uninstall 20
nvm deactivate
```

## Auto Switching with .nvmrc

With `nvm.sh` loaded, entering a directory reads `.nvmrc` and switches to that installed version. If no `.nvmrc` exists anywhere above the current directory, `.node-version` is used. A missing version is not downloaded.

```bash
echo "20" > .nvmrc
cd /my-project
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NVM_DIR` | Node version root (`versions/node`) | `~/.nvm` |
| `NVM_NODEJS_ORG_MIRROR` | Override the Node.js download mirror | unset; downloads use `https://npmmirror.com/mirrors/node` |

```bash
export NVM_DIR="$HOME/.nvm"
export NVM_NODEJS_ORG_MIRROR=https://nodejs.org/dist
```

## Global packages

`npm install -g` installs into the active Node version. `nvm reinstall-packages <version>` copies that version's global packages into the one that is active.

## Commands

| Command | Description |
|---------|-------------|
| `nvm install [version]` | Install a Node.js version |
| `nvm use [version]` | Switch version, or read `.nvmrc` |
| `nvm ls` | List installed versions |
| `nvm alias default [version]` | Set or show the default alias |
| `nvm uninstall <version>` | Remove a version |
| `nvm version` | Active Node version (`none` or `system` when this nvm is not providing it) |
| `nvm --version` | Installed tool version |

## Troubleshooting

### `nvm` is not found

Open a new terminal, or load the profile the installer printed:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

### Version not found after install

```bash
nvm use 22
```

### Auto-switch not working

Confirm the profile still contains the `NVM_DIR` / `nvm.sh` lines above. To stop auto-switch, remove those lines.

---

**Related:** [Why we built znvm](/blog/why-zig) | [GitHub](https://github.com/charlzyx/znvm)
