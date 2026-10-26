---
name: znvm
description: >-
  Use when an agent installs or switches Node versions, npm registries, or
  download mirrors with znvm. Run `nvm --llm` or `nrm --llm` to print this
  guide from the binary. Covers .nvmrc, the China registry, an intranet
  @scope, every `nvm mirror` host, auto-pick, --json, and
  non-interactive flags. There is no MCP server.
---

# znvm

Print this guide from the binary. No skill install is required:

```bash
nvm --llm
nrm --llm
```

`nvm --llm` and `nrm --llm` write this file to stdout and exit. The binary embeds `skills/znvm/SKILL.md`, so the command and the file are the same text.

znvm is the `nvm` binary. `nrm` is the same binary, selected by the command name. `nvm mirror` sets download hosts. Do not start an MCP server for this. Agents already have a shell.

## Install the skill

```bash
npx skills add charlzyx/znvm
```

That reads `skills/znvm/SKILL.md` from `charlzyx/znvm`. If the client cannot install skills, copy this file into its skills directory.

Install the CLI, if `nvm` is missing:

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

`https://znvm.dev/install-as-nvm.sh` is the same script.

After install, check for leftovers from the original nvm (nvm-sh): an old `$NVM_DIR/nvm.sh`, `bash_completion`, `nvm-exec`, or `.git`, and duplicate `NVM_DIR` / `nvm.sh` or `bash_completion` lines in `~/.zshrc`, `~/.bashrc`, and `~/.profile`. Also check old global-package paths in `AGENTS.md`, `CLAUDE.md`, and launchd or systemd units. Ask the user before deleting or editing any of that.

If the shell says command not found:

```bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
```

A new shell also sources `$NVM_DIR/binaries.env`.

## Which command

- Node versions: `nvm install`, `nvm use`, `nvm ls`, `nvm current`, `nvm which`.
- npm registries and `@scope` routes: `nrm`. `nvm registry` edits the same map.
- Download hosts: `nvm mirror`. `nvm mirror ls` prints every supported name.
- `nrm mirror` and `nrm binary` are rejected.
- `nvm install` and `nvm use` with no version read `.nvmrc`, then `.node-version`.

## Recipes

```bash
nvm install
nvm use

nrm use taobao
nvm registry china

nrm scope add @company https://npm.company.example

nvm mirror use china
nvm mirror set electron https://cdn.npmmirror.com/binaries/electron/
nvm mirror set playwright https://cdn.npmmirror.com/binaries/playwright

nrm use auto
nvm mirror use auto
```

`nrm use taobao` and `nvm registry china` set `https://registry.npmmirror.com` and leave scopes in place. `nvm mirror use china` writes the npmmirror hosts, including the Node dist mirror. `nrm use auto` picks one registry and does not change scopes. `nvm mirror use auto` picks a host per tool. Install writes china when the language is zh, and otherwise writes `https://registry.npmjs.org` plus `https://nodejs.org/dist` with no other binary hosts. `NVM_MIRROR=china|official` overrides that. An existing mirror config is kept. `auto` stays manual. `NVM_LANG=zh|en` forces the language; otherwise `LC_ALL`, then `LC_MESSAGES`, then `LANG`. `nvm lang` prints `zh` or `en`. `--json` and `--llm` stay English.

## Download hosts

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

Playwright is the Chromium, Firefox, and WebKit browser download (`PLAYWRIGHT_DOWNLOAD_HOST`). Puppeteer is Chrome for Testing and chrome-headless-shell.

## Non-interactive

A menu opens only when stdin and the menu stream are terminals, `CI` is unset or empty, and `--yes` / `NVM_NONINTERACTIVE` are off. `NVM_NONINTERACTIVE=1`, `true`, and `yes` all count. `0` does not. `NO_COLOR` stays plain ASCII: `nvm ls` has no color sequences.

`--guide-step` draws the menu on stderr and prints shell exports on stdout. Bare `nvm` and bare `nrm` use stdout, so a pipe does not open the menu. Bare `nrm` then prints help and exits 0. Bare `nvm` prints `interactive guide needs a terminal` and exits 1.

## --json

One JSON object on stdout. An error is one object on stderr, stdout is empty, and the exit code matches text mode.

```bash
nvm ls --json
nvm ls-remote --lts --json
nvm current --json
nvm which 20 --json
nvm version --json
nvm --version --json
nrm ls --json
nrm current --json
nrm test --json
nrm scope ls --json
nvm mirror ls --json
nvm mirror test electron --json
```

`nvm version --json` is the active Node version (`{"version":"v20.11.0"}`, `"system"`, or `"none"`). `nvm --version --json`, `znvm version --json`, and `nrm --version --json` are the tool: `{"version":"v2.9.4"}`. A missing match is exit 3 with `{"error":"N/A","exit":3}` on stderr, not a version of `N/A`. Text mode still prints `N/A` on stdout.

With v18.0.0 and v20.11.0 installed, alias `default -> 18`, and no Node on `PATH`:

```json
{"current":null,"versions":[{"version":"v18.0.0","current":false},{"version":"v20.11.0","current":false}],"aliases":[{"name":"default","target":"18"}]}
```

`current` is the active version, `"system"`, or `null`. A version filter or `--no-alias` leaves `aliases` empty. No installed versions is success: `"versions":[]`.

`nvm ls-remote --json` sorts the same way as text: `{"versions":[{"version":"v20.11.0","lts":"Iron"},{"version":"v22.23.4","lts":null}]}`. `--lts` keeps only LTS rows.

`nvm which --json`: `{"version":"v20.11.0","path":".../bin/node"}`.

`nrm ls --json`: `{"registries":[{"name":"npm","url":"https://registry.npmjs.org/","current":false}]}`. `current` matches the `*` line.

`nrm current --json` always has both fields: `{"name":"taobao","url":"https://registry.npmmirror.com/"}`, `{"name":null,"url":null}`, or `name` null when only a raw URL is set. Text `nrm current -u` is unchanged.

`nrm test --json`: `{"registries":[{"name":"npm","ok":true,"seconds":"0.400"}]}`. `seconds` is curl's `%{time_total}` string. `ok:false` sets `seconds` to null. Text mode stays `npm 0.400s` or `npm error`.

`nrm scope ls --json`: `{"scopes":[{"scope":"@company","url":"https://npm.company.example"}]}`. Empty is `{"scopes":[]}`. Text mode still says `No scopes.`

`nvm mirror ls --json`: `{"profile":"official","mirrors":[{"name":"electron","url":null}]}`. `profile` is `official`, `china`, `custom`, or `auto`. An unset host is `null`.

`nvm mirror test electron --json`: `{"mirrors":[{"name":"electron","china":{"ok":true,"seconds":"0.050"},"official":{"ok":true,"seconds":"0.400"}}]}`.

`--json` on any other command exits 1 with `error: --json is not supported for this command.` Bare `--json` exits 1 with `error: --json needs a command.` Flags before `--` are flags. `nvm exec 20 -- --json` leaves `--json` as a program argument and does not switch the output.

Exit codes: 0 success, 1 usage or failure, 3 no matching version, 8 an alias loop, 55 an unsupported option, 127 system node missing or a missing version file. Guide quit is 2. Ctrl-C in a menu is 130. `nvm --help` and `nrm --help` are short usage screens. This file is the reference for files, scopes, menus, and JSON.
