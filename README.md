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
- **Minimal & Focused**: A small native CLI with shell-based environment switching.
- **Smart Architecture**: Zig handles complex SemVer parsing; Shell handles env switching.

## 📦 Quick Install

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

`https://znvm.dev/install-as-nvm.sh` is the same script.

The script installs the `nvm` command, links `nrm` to that same binary, and writes `~/.nvm/nvm.sh`. Running it again is safe. When `nvm --version` already matches this release, the binary stays in place. When the version differs, the previous binary is kept as `nvm.bak` and replaced, and the script prints `ok Upgraded nvm vX -> vY`. It does not duplicate shell config, and it does not delete Node versions already under `~/.nvm/versions/node`. It does not install shell completion.

`nrm` is a relative symlink beside `nvm`. The installer does not replace an existing `nrm`. If that path is already a file, it prints a note and leaves the file in place. If another `nrm` is elsewhere on `PATH`, it prints that path and does not delete it. A new shell moves the `nvm` directory to the front of `PATH`, so the linked `nrm` runs first. `--uninstall` removes this `nvm` binary and the `nrm` symlink when the link points at it, restores `nvm.sh` from `nvm.sh.bak` when that backup exists, removes the `nvm: shell setup` profile block, and does not delete Node versions or a foreign `nrm`.

When it finishes, it prints:

```text
nvm is ready.

Open a new terminal, or run:
  source "~/.bashrc"

export NVM_DIR="$HOME/.nvm"
nvm install 22
nvm use 22
nvm ls
nrm ls

Node versions are stored in $NVM_DIR/versions/node.
```

The profile path in the `source` line is the file the script actually updated.

### Install a specific version

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/v2.2.2/install-as-nvm.sh | bash
```

## ✨ Core Features

- ⚡ **Instant Performance**: Core logic written in Zig for lightning-fast resolution.
- 🍎 **Apple Silicon Friendly**: Automatic architecture detection and Rosetta fallback.
- 🐧 **Unix-First**: Native support for macOS and Linux. Native Windows x64 and ARM64 with PowerShell 7, cmd and Git Bash support is available; see [Windows setup and limits](WINDOWS.md).
- 🔄 **Auto Switch**: Automatic version switching when entering a directory with `.nvmrc`.
- 📦 **Per-version globals**: Global npm packages stay inside each Node version, as they do with nvm.
- ⭐ **Default Version**: Set a default version to use when no `.nvmrc` is present.

## 🛠 Usage

```bash
# Install a version. `node` is the newest release, `lts/*` the newest LTS.
nvm install 22
nvm install --lts
nvm install          # version from .nvmrc, then switch to it

# Switch version. `use` with no version reads .nvmrc from this directory or a parent.
nvm use 20
nvm use
nvm use --lts

# What is active, and where is its node binary?
nvm current
nvm which 20

# List installed versions (`->` marks the active one) and aliases
nvm ls
nvm ls 20
nvm ls-remote --lts

# Default and other aliases. `default` is the same as `alias default`.
nvm alias default 20
nvm alias
nvm unalias work

# Run one command without changing the shell
nvm run 20 --version
nvm exec 20 npm test

# Remove a version, or drop it from PATH
nvm uninstall 20
nvm deactivate
```

Selectors include `20`, `20.11`, `v20.11.0`, `node`, `stable`, `lts/*`, `lts/<name>`, `default`, `current`, and `system`. `.nvmrc` is read from the current directory and its parents. `.node-version` is used only when no `.nvmrc` exists above the current directory. `#` comments are ignored.

In a terminal, `nvm` with no arguments opens an interactive guide. `nvm guide` and `nvm interactive` open the same menu. Up and Down, or k and j, move the highlight. Enter confirms. Esc, q, or Left goes back. A number, then Enter, still picks that row. Ctrl-C restores the terminal and exits. Without a terminal, `nvm` prints a short notice and exits. `NVM_LANG=zh` or `NVM_LANG=en` selects the language. Otherwise NVM uses the first non-empty of `LC_ALL`, `LC_MESSAGES`, and `LANG`. A `zh` tag is Chinese. `C`, `POSIX`, and `en` are neutral: on macOS they use the first `AppleLanguages` value in `~/Library/Preferences/.GlobalPreferences.plist` (or `AppleLocale`), read in process, with no `defaults` command. Any other tag is English. The same menu can edit package-registry routes: several `@scope` registries at once, a separate default, then a sync to npm, yarn, pnpm, and bun.

```bash
nvm registry add @company https://npm.company.example
nvm registry china          # default https://registry.npmmirror.com, scopes stay
nvm registry official       # default https://registry.npmjs.org, scopes stay
nvm registry show
```

The saved map is `$NVM_DIR/registries.json`. Sync rewrites the default registry and `@scope` registry lines in `~/.npmrc`, `~/.yarnrc`, `~/.yarnrc.yml`, the pnpm rc (`~/.config/pnpm/rc`, or `~/Library/Preferences/pnpm/rc` on macOS), and `~/.bunfig.toml`. Other lines in those files stay. A `npmScopes` block in `~/.yarnrc.yml` is replaced by the saved scopes. Download mirrors are `nvm mirror`, so a registry sync leaves them in place.

The same install provides `nrm`. It is this binary when the command name is `nrm`. `nvm use`, `nvm ls`, and `nvm current` always select Node versions. `nrm use`, `nrm ls`, and `nrm current` select registries. `nvm registry` is the prefixed alias for that map.

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

Built-in names are `npm`, `yarn`, `tencent`, `cnpm`, `taobao`, `npmMirror`, and `huawei`. `nrm use` and `nvm registry china` / `official` pick the built-in name when the URL matches, ignoring one trailing slash. `nrm del` does not remove a built-in name. `nrm use auto` measures the registries and writes the fastest one that answers. It does not change `@scope` routes. `nrm test` always measures again. A result is reused for 6 hours from `$NVM_DIR/mirror-latency.json`. In a terminal, `nrm` with no arguments opens a menu for registries, scopes, and tests. Without a terminal it prints help. `nrm add` accepts an optional home argument and ignores it. `nrm` does not accept `binary` or `mirror`.

`nvm mirror` writes the Node dist host and the download hosts tools actually read. The same guide lists it as Mirrors.

```bash
nvm mirror ls
nvm mirror use china
nvm mirror use auto
nvm mirror set electron https://cdn.npmmirror.com/binaries/electron/
nvm mirror reset
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

`official` clears them. `set` stores one URL. `auto` measures each China host against its upstream host and keeps the faster one. npm, pnpm, and yarn v1 keys go in their rc files, inside a `# nvm binaries` block. Env-only values go in `$NVM_DIR/binaries.env`, which `nvm.sh` sources. `reset` deletes that file and the block, and leaves registry lines, scopes, and other settings. Clearing the Node mirror falls back to znvm's usual download host. To force nodejs.org, `nvm mirror set node https://nodejs.org/dist`. Install writes the china preset when the language is zh, and otherwise writes `https://registry.npmjs.org` plus `https://nodejs.org/dist` with no other binary hosts; `NVM_MIRROR=china|official` overrides that, an existing mirror config is kept, and `nvm mirror use auto` / `nrm use auto` stay manual.

Docker image mirrors are not set here. Pointing the Docker daemon at a mirror needs a privileged config and a daemon restart, so that stays a later change.

### Differences from nvm

Node versions live in `$NVM_DIR/versions/node` (default `~/.nvm`), including versions nvm already installed. Node older than 0.12 is read from `$NVM_DIR/vX.Y.Z`, matching nvm.

The download mirror defaults to `https://npmmirror.com/mirrors/node`. Set `NVM_NODEJS_ORG_MIRROR` to use a different mirror.

`nvm version` prints the active Node version (`none` or `system` when this nvm is not providing it). `nvm --version` prints the installed tool version.

There is no `nvm completion` command, and the installer does not add shell completion.

Shell setup switches to `.nvmrc` when you enter a directory, then the default alias. It does not download a missing version. `.node-version` is used only when no `.nvmrc` exists anywhere above the current directory (nvm 0.40 reads `.nvmrc` only). `#` comments are ignored.

Global npm packages stay inside each Node version, as they do with nvm. `reinstall-packages` and `--reinstall-packages-from` copy them to the version you are switching to.

Not implemented, because they are not just a different default:

- `-s` compiles Node from source. This `nvm` installs official binaries only.
- io.js and the `unstable` alias are retired and are not on the Node mirror.
- `set-colors` only changes terminal colors in nvm.sh. `nvm ls` prints plain text.
- Docker image mirrors. `nvm mirror` covers tool download hosts. The Docker daemon is a separate privileged config.

## ⚙️ Shell Setup

`install-as-nvm.sh` appends this to the shell profile it updates (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```bash
# nvm: shell setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

Open a new terminal, or `source` that profile. The command is `nvm`. Versions live in `$NVM_DIR/versions/node`.

## Agents

Run the CLI. There is no MCP server. The zero-install way to learn the tool is:

```bash
nvm --llm
nrm --llm
```

Both print [`skills/znvm/SKILL.md`](skills/znvm/SKILL.md). The binary embeds that file. The same text is [llm.txt](https://znvm.dev/llm.txt) (`/llms.txt` is an alias).

```bash
npx skills add charlzyx/znvm
```

That installs `skills/znvm/SKILL.md`. Copy that file if the client cannot install skills.

`nvm` selects Node versions. `nrm` selects npm registries and `@scope` routes. `nvm mirror` selects every download host in the table above. `nvm install` and `nvm use` with no version read `.nvmrc`, then `.node-version`.

Menus open only when stdin and the menu stream are terminals, `CI` is unset or empty, and neither `--yes` nor `NVM_NONINTERACTIVE=1` (also `true` or `yes`) is set. `NO_COLOR` stays plain ASCII. `--guide-step` draws on stderr.

`--json` writes one object to stdout for `ls`, `ls-remote`, `current`, `which`, `version`, `--version`, `nrm ls`, `nrm current`, `nrm test`, `nrm scope ls`, `nvm mirror ls`, and `nvm mirror test`. An error is `{"error":"...","exit":N}` on stderr, stdout is empty, and the exit code is the same as text mode: 0 success, 1 usage or failure, 3 no matching version, 8 an alias loop, 55 an unsupported option, 127 system node missing or a missing version file. Guide quit is 2. Ctrl-C in a menu is 130. `nvm --help` is a short command list. The behavior above is the reference.

`nvm ls --json` with v18.0.0 and v20.11.0 installed, alias `default -> 18`, and no Node on `PATH`:

```json
{"current":null,"versions":[{"version":"v18.0.0","current":false},{"version":"v20.11.0","current":false}],"aliases":[{"name":"default","target":"18"}]}
```

`current` is the active version, `"system"`, or `null`. A version filter or `--no-alias` leaves `aliases` empty. `nvm ls-remote --json` uses `{"versions":[{"version":"v20.11.0","lts":"Iron"}]}` (`lts` is `null` when the release is not LTS). `nvm which --json` is `{"version":"v20.11.0","path":".../bin/node"}`. `nrm current --json` is `{"name":"taobao","url":"https://registry.npmmirror.com/"}` or `{"name":null,"url":null}`. `nrm test --json` keeps curl's time string: `{"registries":[{"name":"npm","ok":true,"seconds":"0.400"}]}` (`seconds` is `null` when `ok` is false). `nvm mirror ls --json` is `{"profile":"official","mirrors":[{"name":"electron","url":null}]}`. `nvm mirror test electron --json` reports `china` and `official`, each with `ok` and `seconds`.

If `nvm` is not found: `export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"`. A new shell also sources `$NVM_DIR/binaries.env`.

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
