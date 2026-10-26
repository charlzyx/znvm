# Native Windows support

Tracked by #27. Native Windows x64 and ARM64 support PowerShell 7, cmd, and Git Bash,
without administrator privileges, symlinks, junctions, or persistent system PATH
changes. Node uses the official Windows ZIP layout. Switching changes only the
current shell session. Existing macOS/Linux behavior must remain unchanged.

Validation targets: unit tests, Linux/macOS regression suites, and native
`windows-latest` (x64) and `windows-11-arm` (ARM64) smoke tests with temporary HOME/USERPROFILE/NVM_DIR. Cross
compilation is a build check, not Windows runtime validation.

The first implementation targets install/list/which/current/use/run/exec,
aliases and removal. Automatic directory hooks and native interactive arrow-key
menus are not part of this support claim. This implements znvm’s nvm-compatible
CLI, not every feature of the separate nvm-windows project.

See the PR and release checks for native x64 and ARM64 verification results.

## Download and use (PowerShell 7, Windows x64 or ARM64)

Download the matching ZIP from [v2.10.0](https://github.com/charlzyx/znvm/releases/tag/v2.10.0):

- x64: `znvm-v2.10.0-x86_64-windows.zip`
- ARM64: `znvm-v2.10.0-aarch64-windows.zip`

Compare `Get-FileHash <downloaded-file> -Algorithm SHA256` with the release's
`SHA256SUMS`, then extract the ZIP into a user-owned folder. Each package contains real
`bin/nvm.exe` and `bin/nrm.exe`, plus the separate `cmd` shim directory.
The hashes check transfer integrity; obtain both files from the official release.

```powershell
$setup = & ./bin/nvm.exe env --shell powershell
if ($LASTEXITCODE -eq 0) { Invoke-Expression ($setup -join "`n") }
nvm install 22
nvm use 22
nvm current
nvm exec 22 npm --version
nvm deactivate
```

To build from source, install Zig **0.17.0** and run
`zig build -Doptimize=ReleaseSafe`; the executable is `zig-out/bin/nvm.exe`.
On ARM64, use native ARM64 Zig or explicitly pass `-Dtarget=aarch64-windows-gnu`.

This installs the `nvm` function in this session only. Repeat `env` in a new
terminal. No profile or persistent PATH is edited. `NVM_DIR` overrides the data
root, otherwise `HOME` then `USERPROFILE` supplies `.nvm`. Existing nvm-windows
symlink installations are not imported. The official Windows ZIPs place
`node.exe` and `node_modules` directly inside each version directory.
Windows' bundled `curl.exe` must be on PATH. ZIP extraction is native and
supports Unicode paths without a tar subprocess. `nvm exec` handles
`npm` and `npx` through their JavaScript entrypoints. Other commands use Zig's
Windows process launcher; batch files use Windows shell semantics. Prefer
explicit `.exe` commands when arguments must remain literal.

For the registry CLI, run the packaged `./bin/nrm.exe ls`.

## cmd

From the extracted package, initialize the current session:

```bat
cmd /V:OFF
cmd\init.cmd
nvm install 22
nvm use 22
node --version
nvm deactivate
```

In another batch file use `call "C:\path to package\cmd\init.cmd"` and
`call nvm ...`. Initialization puts the separate shim directory before `bin` on
this session's PATH. Do not run from inside `bin`: cmd searches the current
directory before PATH, and a direct `nvm.exe` process cannot change its parent
environment. Use explicit `nvm.cmd` when necessary. Delayed expansion (`/V:ON`)
is refused, rather than silently corrupting paths containing `!`. Environment
updates temporarily select UTF-8 console codepage and restore the original;
this briefly affects the shared console, not system settings. Oversized or
multiline environment updates are rejected. Ordinary command output is never
executed as batch code. As with any cmd command line, literal percent signs in
a directly typed path must follow cmd’s percent-expansion/escaping rules; the
wrapper preserves literal percent signs once they have reached its environment.

## Git Bash

```bash
eval "$(./bin/nvm.exe env --shell bash)"
nvm install 22
nvm use 22
node --version
nvm deactivate
```

Only the trusted initializer is evaluated. Mutation responses are allowlisted
Base64 data, not shell code. Windows PATH lists are converted with `cygpath`.
Native arguments are forwarded literally with MSYS automatic argument conversion
disabled. For `run` and `exec … node` / `node.exe`, the first script operand
(or the operand immediately after Node’s `--`) is converted from a POSIX path
when it resolves to a regular file. This also works with aliases and `.nvmrc`.
JavaScript supplied to `-e` / `-p` and arguments after the script remain literal.
We do not parse arbitrary Node flags: when flags precede the script, use
`cygpath -w` explicitly for that script path. Other native commands likewise
require Windows-form path arguments.
No other shell's environment or startup profile is changed.

Run `zig build test` and `./scripts/windows-smoke.ps1 -ExpectedArch x64` (or `arm64`) for native validation.
The smoke test uses a disposable data root and restores its process environment.
Mirror-generated `binaries.env` remains POSIX shell syntax and is not sourced
by PowerShell yet; direct registry configuration and Node mirror selection
remain available. Use explicit commands rather than interactive menus.

ZIPs are streamed into a fresh sibling staging directory, checked for the exact
requested distribution root and a regular `node.exe`, then installed with a
non-replacing atomic rename. Validation rejects traversal, Windows drive/ADS
syntax, reserved device names, normalized aliases and duplicate paths. Every
regular output file is checked against its declared length and CRC32 before
publication (CRC32 detects corruption, not publisher authenticity). Limits are 100,000 entries,
1 GiB total uncompressed data and 16 MiB total filename data. Failure removes
only the new staging directory, not an existing installation.
