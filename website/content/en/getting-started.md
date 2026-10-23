# Quick start

`nvm` and `nrm`, written in Zig. Versions live in `$NVM_DIR/versions/node` (default `~/.nvm`). Downloads use npmmirror. 2026-10-22: warm shell startup 3.31 ms, cold 5.01 ms.

`nvm` with no arguments opens a guide. No terminal: it prints a notice and exits.

## For agents

```bash
nvm --llm
nrm --llm
```

Same text as `skills/znvm/SKILL.md` and [llm.txt](https://znvm.dev/llm.txt). The binary embeds that file.

```bash
npx skills add charlzyx/znvm
```

That installs `skills/znvm/SKILL.md`. No MCP server.

`nvm` selects Node. `nrm` selects registries and `@scope` routes. `nvm mirror` selects download hosts. `nvm install` and `nvm use` with no version read `.nvmrc`, then `.node-version`.

`--json` prints one object for `nvm ls`, `nvm ls-remote` (`--lts` too), `nvm current`, `nvm which`, `nvm version`, `nvm --version`, `nrm ls`, `nrm current`, `nrm test`, `nrm scope ls`, `nvm mirror ls`, and `nvm mirror test`. Errors are `{"error":"...","exit":N}` on stderr, with empty stdout. Exit codes: 0 ok, 1 usage or failure, 3 no match, 8 alias loop, 55 bad option, 127 missing system node or version file.

With v18.0.0 and v20.11.0 installed, alias `default -> 18`, and no Node on `PATH`, `nvm ls --json` prints:

```json
{"current":null,"versions":[{"version":"v18.0.0","current":false},{"version":"v20.11.0","current":false}],"aliases":[{"name":"default","target":"18"}]}
```

Menus need a terminal on stdin and on the menu stream. `--yes`, `NVM_NONINTERACTIVE=1` (`true` or `yes`), or a non-empty `CI` keeps them closed. `NO_COLOR` is plain ASCII. `--guide-step` draws on stderr.

If `nvm` is not found:

```bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
```

## Installation

### Install

```bash
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

When it finishes, it prints:

```text
nvm
Node versions go in ~/.nvm. Downloads use https://npmmirror.com/mirrors/node.

> Downloading nvm v2.7.0 (x86_64-linux)...
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

`source` the profile it printed (`~/.bashrc`, `~/.zshrc`, or `~/.profile`). Running it again is safe. A matching `nvm --version` keeps the binary. A different version is saved as `nvm.bak` and replaced. It does not duplicate the shell block or delete Node versions.

### What the installer does

1. Detects your platform (macOS/Linux) and architecture (x64/arm64)
2. Installs the `nvm` command, links `nrm` to it, and writes `~/.nvm/nvm.sh`
3. Appends the `NVM_DIR` startup lines to your shell profile
4. Leaves existing Node versions in `$NVM_DIR/versions/node` in place

`nrm` is a relative symlink next to `nvm`. An existing path is left in place. A foreign `nrm` on `PATH` is left in place. A new shell puts this directory first. `--uninstall` removes the `nvm` binary, the `nrm` link when it points at `nvm`, and the shell block. It does not delete Node versions or a foreign `nrm`.

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

Number keys and Enter. Registries and Mirrors are on the menu. Prompts are Chinese when `LC_ALL`, `LC_MESSAGES`, or `LANG` starts with `zh`.

## Registries

One default registry plus `@scope` routes, written for npm, yarn, pnpm, and bun.

```bash
nvm registry show
nvm registry set-default https://registry.npmmirror.com
nvm registry add @company https://npm.company.example
nvm registry remove @company
nvm registry china
nvm registry official
nvm registry sync
```

`china` sets `https://registry.npmmirror.com`. `official` sets `https://registry.npmjs.org`. Scopes stay. The map is `$NVM_DIR/registries.json`. Sync writes `~/.npmrc`, `~/.yarnrc`, `~/.yarnrc.yml`, the pnpm rc, and `~/.bunfig.toml`, and leaves other settings and `nvm mirror` hosts.

## nrm

`nrm` is this binary under another name. `nvm use`, `ls`, and `current` are Node. `nrm use`, `ls`, and `current` are registries. No terminal: `nrm` prints help. `nvm.sh` wraps `nvm` only.

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
```

Built-ins: `npm`, `yarn`, `tencent`, `cnpm`, `taobao`, `npmMirror`, `huawei`. `nrm use taobao` and `nvm registry china` are the same URL. One trailing slash still matches. `nrm del` refuses a built-in. `nrm use auto` writes the fastest registry and leaves scopes. `nrm test` measures again. A result is kept for 6 hours.

## Download mirrors

```bash
nvm mirror ls
nvm mirror use china
nvm mirror use official
nvm mirror use auto
nvm mirror set electron https://cdn.npmmirror.com/binaries/electron/
nvm mirror reset
nvm mirror test
```

`china` writes npmmirror hosts for Node, Electron, electron-builder, Playwright, Cypress, puppeteer, sharp, libvips, node-sass, and the other common tools. `official` clears them. `auto` keeps the faster side of each tool. npm, pnpm, and yarn v1 keys go in their rc files. Env values go in `$NVM_DIR/binaries.env`, sourced by `nvm.sh`. `reset` removes that file and the `# nvm binaries` block. Scopes stay. Nothing runs on install.

Clearing the Node mirror falls back to the usual host. Force nodejs.org with `nvm mirror set node https://nodejs.org/dist`.

Docker is not set here. That needs a daemon config and a restart.

## Usage

### Install Node.js

`22` means the latest v22:

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

`default` is used when the directory has no `.nvmrc` and no `.node-version`.

### Uninstall a Version

```bash
nvm uninstall 20
nvm deactivate
```

## Auto Switching with .nvmrc

With `nvm.sh` loaded, entering a directory reads `.nvmrc`, then `.node-version`. A missing version is not downloaded.

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

`npm install -g` installs into the active Node. `nvm reinstall-packages <version>` copies that version's global packages into the active one.

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
| `nvm mirror` | Node dist host and download mirrors |
| `nrm` | Registries, scope routes, test, and auto |

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

**Related:** [Why Zig](/blog/why-zig) | [GitHub](https://github.com/charlzyx/znvm)
