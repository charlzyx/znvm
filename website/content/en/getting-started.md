# Quick start

NVM and NRM, written in Zig. Versions live in `$NVM_DIR/versions/node` (default `~/.nvm`). Downloads use npmmirror. 2026-10-22: warm shell startup 3.31 ms, cold 5.01 ms.

Run `nvm` to open the guide. With no terminal it prints one line and exits.

## Installation

### Install

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

`https://znvm.dev/install-as-nvm.sh` is the same script.

When it finishes, it prints:

```text
nvm
Node versions go in ~/.nvm. Downloads use https://npmmirror.com/mirrors/node.

> Downloading nvm v2.8.0 (x86_64-linux)...
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

Up and down, then Enter. A number still works. Registries and Mirrors are on the menu. Prompts are Chinese when `LC_ALL`, `LC_MESSAGES`, or `LANG` starts with `zh`.

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

`nvm mirror ls` prints every supported name. `china` writes these hosts.

| name | covers | env / npmrc |
| --- | --- | --- |
| electron | Electron | `ELECTRON_MIRROR`, npmrc `electron_mirror` |
| electron-builder | electron-builder binaries | `ELECTRON_BUILDER_BINARIES_MIRROR`, npmrc `electron_builder_binaries_mirror` |
| playwright | Chromium, Firefox, and WebKit browser downloads | `PLAYWRIGHT_DOWNLOAD_HOST` |
| cypress | Cypress zip | `CYPRESS_DOWNLOAD_PATH_TEMPLATE` |
| puppeteer | Chrome for Testing and chrome-headless-shell | `PUPPETEER_DOWNLOAD_HOST`, `PUPPETEER_DOWNLOAD_BASE_URL`, `PUPPETEER_CHROME_DOWNLOAD_BASE_URL`, `PUPPETEER_CHROME_HEADLESS_SHELL_DOWNLOAD_BASE_URL` |
| node-sass | node-sass | `SASS_BINARY_SITE`, npmrc `sass_binary_site` |
| sharp | sharp prebuild | `npm_config_sharp_binary_host`, npmrc `sharp_binary_host` |
| libvips | libvips for sharp | `npm_config_sharp_libvips_binary_host`, npmrc `sharp_libvips_binary_host` |
| node | Node dist | `NODEJS_ORG_MIRROR`, `NVM_NODEJS_ORG_MIRROR` |
| chromedriver | ChromeDriver | `CHROMEDRIVER_CDNURL` |
| edgedriver | EdgeDriver | `EDGEDRIVER_CDNURL` |
| operadriver | OperaDriver | `OPERADRIVER_CDNURL` |
| phantomjs | PhantomJS | `PHANTOMJS_CDNURL` |
| node-swc | SWC | `SWC_BINARY_SITE` |
| nwjs | NW.js | `NWJS_URLBASE` |
| sentry-cli | sentry-cli | `SENTRYCLI_CDNURL` |
| saucectl | saucectl | `SAUCECTL_INSTALL_BINARY_MIRROR` |
| node-re2 | node-re2 | `RE2_DOWNLOAD_MIRROR`, `RE2_DOWNLOAD_SKIP_PATH` |
| prisma | Prisma engines | `PRISMA_ENGINES_MIRROR` |
| better-sqlite3 | better-sqlite3 prebuild | `npm_config_better_sqlite3_binary_host`, npmrc `better_sqlite3_binary_host` |
| isolated-vm | isolated-vm prebuild | `npm_config_isolated_vm_binary_host`, npmrc `isolated_vm_binary_host` |
| keytar | keytar prebuild | `npm_config_keytar_binary_host`, npmrc `keytar_binary_host` |
| robotjs | robotjs prebuild | `npm_config_robotjs_binary_host`, npmrc `robotjs_binary_host` |
| gl | headless-gl prebuild | `npm_config_gl_binary_host`, npmrc `gl_binary_host` |
| corepack | Corepack npm registry | `COREPACK_NPM_REGISTRY` |
| ripgrep | ripgrep-prebuilt | `RIPGREP_PREBUILT_BINARIES_MIRROR` |
| sqlite3 | sqlite3 prebuild | `npm_config_sqlite3_binary_host`, npmrc `sqlite3_binary_host` |
| canvas | node-canvas prebuild | `npm_config_canvas_binary_host`, npmrc `canvas_binary_host` |
| grpc | grpc native binding (module `grpc_node`) | `npm_config_grpc_node_binary_host_mirror`, npmrc `grpc_node_binary_host_mirror` |
| grpc-tools | grpc-tools binaries | `npm_config_grpc_tools_binary_host_mirror`, npmrc `grpc_tools_binary_host_mirror` |
| nodejieba | nodejieba prebuild | `npm_config_nodejieba_binary_host_mirror`, npmrc `nodejieba_binary_host_mirror` |
| xprofiler | xprofiler prebuild | `npm_config_xprofiler_binary_host_mirror`, npmrc `xprofiler_binary_host_mirror` |
| gdal-async | node-gdal-async prebuild (module `gdal`) | `npm_config_gdal_binary_host_mirror`, npmrc `gdal_binary_host_mirror` |
| ali-zeromq | zeromq binding (module `zmq`) | `npm_config_zmq_binary_host_mirror`, npmrc `zmq_binary_host_mirror` |
| ali-usb_ctl | usb_ctrl binding | `npm_config_usb_ctrl_binary_host_mirror`, npmrc `usb_ctrl_binary_host_mirror` |

Not set. cnpm rewrites package files (`replaceHost` / `replaceHostFiles`), and no config key redirects the download: jpegtran-bin, cwebp-bin, zopflipng-bin, optipng-bin, mozjpeg, gifsicle, pngquant-bin, pngcrush-bin, jpeg-recompress-bin, advpng-bin, pngout-bin, jpegoptim-bin, flow-bin, @tensorflow/tfjs-node.

Not set. The installer has no verified host env, or the mirror path does not match that installer: @journeyapps/sqlcipher, leveldown, utf-8-validate, argon2, fsevents, couchbase, wrtc, skia-canvas, libpg-query, @ali/s2.

`official` clears them. `auto` keeps the faster side of each tool. npm, pnpm, and yarn v1 keys go in their rc files. Env values go in `$NVM_DIR/binaries.env`, sourced by `nvm.sh`. `reset` removes that file and the `# nvm binaries` block. Scopes stay. Nothing runs on install.

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
