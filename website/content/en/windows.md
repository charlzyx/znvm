---
title: Windows setup
description: Native Windows x64 and ARM64, with PowerShell 7, cmd and Git Bash.
---

## Download v2.10.0

Choose the architecture shown in **Windows Settings → System → About → System type**. Download the ZIP and checksum list from the same official release:

| Windows device | Package |
| --- | --- |
| Intel / AMD, x64 | [Download x64 ZIP](https://github.com/charlzyx/znvm/releases/download/v2.10.0/znvm-v2.10.0-x86_64-windows.zip) |
| ARM64 | [Download ARM64 ZIP](https://github.com/charlzyx/znvm/releases/download/v2.10.0/znvm-v2.10.0-aarch64-windows.zip) |

[SHA256SUMS](https://github.com/charlzyx/znvm/releases/download/v2.10.0/SHA256SUMS) · [Release notes](https://github.com/charlzyx/znvm/releases/tag/v2.10.0)

In your download directory, compare the hash with the line for your exact ZIP filename in `SHA256SUMS`. For ARM64, replace `x86_64` with `aarch64`:

```powershell
Get-FileHash .\znvm-v2.10.0-x86_64-windows.zip -Algorithm SHA256
Get-Content .\SHA256SUMS
```

Stop if they differ. The checksum checks file integrity, not independent publisher identity: obtain both files from the official release above.

Extract into a **user-owned folder**, then open a terminal in the package root. Keep the whole layout: real `bin/nvm.exe` and `bin/nrm.exe`, plus the separate `cmd` directory containing `init.cmd`, `nvm.cmd` and `finish.cmd`. Do not move the binaries or shims apart, or initialize cmd from inside `bin`.

No administrator rights, Developer Mode, symlinks or junctions are required. Initialization changes only the current shell session, not your profile or persistent/system PATH. Repeat it in a new terminal. Windows' bundled `curl.exe` must be on PATH.

## PowerShell 7

From the package root:

```powershell
$setup = & ./bin/nvm.exe env --shell powershell
if ($LASTEXITCODE -ne 0) { throw 'nvm initialization failed' }
Invoke-Expression ($setup -join "`n")
nvm install 22
nvm use 22
node --version
nvm current
nvm exec 22 npm --version
./bin/nrm.exe ls
nvm deactivate
```

Only the trusted initializer is evaluated. Switching responses are fixed, allowlisted data, not arbitrary code. `nvm exec 22 npm` and `npx` call JavaScript entrypoints without an extra cmd parse.

## cmd: delayed expansion off

From the package root, open cmd with delayed expansion disabled and initialize:

```bat
cmd /V:OFF
cmd\init.cmd
nvm install 22
nvm use 22
node --version
nrm ls
nvm deactivate
```

In another batch file use `call "C:\path to package\cmd\init.cmd"` and `call nvm ...`. Initialization puts the separate shim directory before `bin` on this session's PATH. Directly running `nvm.exe` cannot change its parent shell; use initialized `nvm` or explicitly `nvm.cmd`.

`/V:ON` is refused to protect paths containing `!`. Literal `%` in a typed path still follows cmd's expansion/escaping rules. Environment updates briefly select UTF-8 console codepage and restore the previous value; system settings are unchanged. Oversized or multiline environment updates are rejected.

## Git Bash

From the package root:

```bash
setup=$(./bin/nvm.exe env --shell bash) && eval "$setup"
nvm install 22
nvm use 22
node --version
./bin/nrm.exe ls
nvm deactivate
```

The wrapper uses Git Bash's `cygpath` and `base64`. Only initialization uses `eval`; switching responses are allowlisted Base64 data. Native arguments are forwarded literally, with MSYS automatic argument conversion disabled.

For `nvm run` and `nvm exec … node` / `node.exe`, the first script operand, or the operand immediately after Node's `--`, is converted from POSIX to Windows form if it resolves to a regular file. Aliases and implicit `.nvmrc` selection work too. JavaScript passed to `-e` / `-p` and trailing arguments stay literal. When other Node flags precede the script, use `cygpath -w` explicitly for that path. Other native commands also need Windows-form path arguments.

**ARM64 boundary:** nvm and Node were verified as native ARM64 processes on Windows ARM64. The hosted runner's Git launcher is ARM64, but its `usr/bin/bash.exe` runtime is x64 under Windows emulation. This is not a native-ARM64 Bash runtime claim.

## Storage and limits

- `NVM_DIR` overrides the data root. Otherwise `HOME`, then `USERPROFILE`, supplies `.nvm`. Versions live in `versions/node`; each version contains `node.exe` and `node_modules` directly.
- Supported commands include `install`, `use`, `ls`, `current`, `which`, `run`, `exec`, aliases, `uninstall` and `deactivate`. `nvm use` reads `.nvmrc`; automatic directory hooks and interactive arrow-key menus are not supported on Windows yet.
- Existing nvm-windows symlink installations are not imported. This is znvm's nvm-compatible CLI, not the separate nvm-windows project.
- Registry commands and Node mirror selection are available. Mirror-generated `binaries.env` remains POSIX syntax and is not sourced by PowerShell. Prefer explicit `.exe` commands for literal arguments; batch files follow Windows shell semantics.
- `nvm uninstall 22` removes that version and deactivates it if active. `nvm deactivate` alone leaves installed versions untouched.

[All commands](/getting-started) · [Source and verification details](https://github.com/charlzyx/znvm/blob/v2.10.0/WINDOWS.md)
