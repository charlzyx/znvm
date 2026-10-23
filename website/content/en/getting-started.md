# Get Started

**znvm** — **Zero-overhead Node Version Manager**

A **Node.js version manager** built with Zig. After install, the commands are `nvm` and `nrm`. Versions live in `$NVM_DIR/versions/node` (default `~/.nvm`). The default download mirror is npmmirror. On 2026-10-22, warm shell startup was **3.31 ms** and cold shell startup was **5.01 ms** (see the homepage tables).

In a terminal, `nvm` with no arguments opens an interactive guide (`nvm guide` does the same). Without a terminal, it prints a short notice and exits.

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

When it finishes, it prints:

```text
nvm
Node versions go in ~/.nvm. Downloads use https://npmmirror.com/mirrors/node.

> Downloading nvm v2.6.0 (x86_64-linux)...
ok Linked /home/user/.nvm/nrm -> nvm
ok Wrote /home/user/.nvm/nvm.sh
> Added nvm startup to /home/user/.bashrc

nvm is ready.

Open a new terminal, or run:
  source "/home/user/.bashrc"

export NVM_DIR="/home/user/.nvm"
nvm install 22
nvm use 22
nvm ls
nrm ls

Node versions are stored in $NVM_DIR/versions/node.
Downloads use https://npmmirror.com/mirrors/node unless NVM_NODEJS_ORG_MIRROR is set.
```

The `source` path is the profile the script actually updated (`~/.bashrc`, `~/.zshrc`, or `~/.profile`). Running the script again is safe. When `nvm --version` already matches this release, the binary stays in place. When the version differs, the previous binary is kept as `nvm.bak` and replaced. It does not duplicate that block, and it does not delete Node versions already under `~/.nvm/versions/node`.

### What the installer does

1. Detects your platform (macOS/Linux) and architecture (x64/arm64)
2. Installs the `nvm` command, links `nrm` to it, and writes `~/.nvm/nvm.sh`
3. Appends the `NVM_DIR` startup lines to your shell profile
4. Leaves existing Node versions in `$NVM_DIR/versions/node` in place

The `nrm` link is a relative symlink in the same directory as `nvm`. If that path already exists, the installer leaves it unchanged and says so. If another `nrm` is on `PATH`, the installer prints that path and does not delete it. A new shell moves the `nvm` directory to the front of `PATH`, so this `nrm` runs first. `install-as-nvm.sh --uninstall` removes the `nvm` binary and the `nrm` link when the link points at it, restores or removes the shell block, and does not delete Node versions or a foreign `nrm`.

### Shell setup

The installer writes:

```bash
# nvm: shell setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

Open a new terminal, or `source` that profile. The commands after that are `nvm` and `nrm`.

## Interactive guide

```bash
nvm
```

The menu uses number keys and Enter. It installs, switches, lists, and uninstalls by running the same `nvm` commands as the sections below. Chinese prompts are used when `LC_ALL`, `LC_MESSAGES`, or `LANG` starts with `zh`.

## Registries

`nvm registry` keeps one default registry and any number of `@scope` routes, then writes them for npm, yarn, pnpm, and bun. The interactive menu can view that map, add or edit a scope, delete one, set the default, sync every file, switch to the China default while keeping scopes, or restore the official npm registry.

```bash
nvm registry show
nvm registry set-default https://registry.npmmirror.com
nvm registry add @company https://npm.company.example
nvm registry remove @company
nvm registry china
nvm registry official
nvm registry sync
```

`china` sets the default to `https://registry.npmmirror.com`. `official` sets it to `https://registry.npmjs.org`. Scope routes stay in place either way. The map is stored in `$NVM_DIR/registries.json`. Sync updates `~/.npmrc`, `~/.yarnrc`, `~/.yarnrc.yml`, the pnpm rc, and `~/.bunfig.toml`. Other settings in those files stay. Binary download mirrors are `nrm binary`, so a registry sync leaves them in place.

## nrm

`nrm` is the same binary, selected by the command name. `nvm use`, `nvm ls`, and `nvm current` always select Node versions. `nrm use`, `nrm ls`, and `nrm current` select registries. In a terminal, `nrm` with no arguments opens a menu for registries, scopes, binary mirrors, and tests. Without a terminal it prints help. The shell function from `nvm.sh` wraps `nvm` only.

```bash
nrm ls
nrm use taobao
nrm current
nrm current -u
nrm add local http://127.0.0.1:4873
nrm del local
nrm test taobao
nrm use auto
nrm scope add @company https://npm.company.example
nrm scope ls
nrm scope del @company
nrm binary ls
nrm binary use china
nrm binary test
nrm binary use auto
nrm binary set electron https://cdn.npmmirror.com/binaries/electron/
nrm binary reset
```

Built-in names are `npm`, `yarn`, `tencent`, `cnpm`, `taobao`, `npmMirror`, and `huawei`. `nrm use taobao` and `nvm registry china` select the same npmmirror URL. A single trailing slash does not change the match. `nrm del` refuses a built-in name. `nvm registry` remains available.

`nrm use auto` measures every registry and writes the fastest one that answers. `nrm test` always measures again. A fresh result is kept for 6 hours in `$NVM_DIR/mirror-latency.json`. `@scope` routes are not changed.

`nrm binary use china` writes the npmmirror download hosts (Electron, electron-builder, Playwright, Cypress, puppeteer, sharp, libvips, node-sass, and the other common ones). `official` clears them. `auto` keeps the faster side of each pair. npm, pnpm, and yarn v1 keys go in their rc files. Env-only values go in `$NVM_DIR/binaries.env`, which `nvm.sh` sources. `reset` removes that file and the `# nvm binaries` block only.

In a terminal, `nrm` opens a menu: registries, scopes, binary mirrors, and test / auto.

Docker image mirrors are not set here. That needs a privileged daemon config and a restart, and it is left for later.

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
