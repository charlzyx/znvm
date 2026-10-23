---
name: znvm
description: >-
  Use when an agent installs or switches Node versions, npm registries, or
  download mirrors with znvm. Run `nvm --llm` or `nrm --llm` to print this
  guide from the binary. Covers .nvmrc, the China registry, an intranet
  @scope, Electron and Playwright mirrors, auto-pick, --json, and
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
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

If the shell says command not found:

```bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
```

A new shell also sources `$NVM_DIR/binaries.env`.

## Which command

- Node versions: `nvm install`, `nvm use`, `nvm ls`, `nvm current`, `nvm which`.
- npm registries and `@scope` routes: `nrm`. `nvm registry` edits the same map.
- Electron, Playwright, Cypress, and the other download hosts: `nvm mirror`.
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

`nrm use taobao` and `nvm registry china` set `https://registry.npmmirror.com` and leave scopes in place. `nvm mirror use china` writes the npmmirror hosts, including the Node dist mirror. `nrm use auto` picks one registry and does not change scopes. `nvm mirror use auto` picks a host per tool. Neither runs on install.

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

`nvm version --json` is the active Node version (`{"version":"v20.11.0"}`, `"system"`, or `"none"`). `nvm --version --json`, `znvm version --json`, and `nrm --version --json` are the tool: `{"version":"v2.7.0"}`. A missing match is exit 3 with `{"error":"N/A","exit":3}` on stderr, not a version of `N/A`. Text mode still prints `N/A` on stdout.

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

Exit codes: 0 success, 1 usage or failure, 3 no matching version, 8 an alias loop, 55 an unsupported option, 127 system node missing or a missing version file. Guide quit is 2.
