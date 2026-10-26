# Native Windows support (draft)

Tracked by #27. This branch develops native Windows x64 with PowerShell 7,
without administrator privileges, symlinks, junctions, or persistent system PATH
changes. Node uses the official Windows ZIP layout. Switching changes only the
current PowerShell process. Existing macOS/Linux behavior must remain unchanged.

Validation targets: unit tests, Linux/macOS regression suites, and native
`windows-latest` smoke tests with temporary HOME/USERPROFILE/NVM_DIR. Cross
compilation is a build check, not Windows runtime validation.

The first implementation targets install/list/which/current/use/run/exec,
aliases and removal. cmd.exe integration, automatic directory hooks, native
interactive arrow-key menus and Windows ARM64 runtime validation are not part
of the initial support claim. No release is published by this PR.

Implementation and verification are in progress; see the PR checks for results.

## Build and use (PowerShell 7, Windows 10/11 x64)

Install Zig **0.17.0**, then from this checkout:

```powershell
zig build -Doptimize=ReleaseSafe
$setup = & ./zig-out/bin/znvm.exe env
if ($LASTEXITCODE -eq 0) { Invoke-Expression ($setup -join "`n") }
nvm install 22
nvm use 22
nvm current
nvm exec 22 npm --version
nvm deactivate
```

This installs the `nvm` function in this session only. Repeat `env` in a new
terminal. No profile or persistent PATH is edited. `NVM_DIR` overrides the data
root, otherwise `HOME` then `USERPROFILE` supplies `.nvm`. Existing nvm-windows
symlink installations are not imported. The official Windows ZIPs place
`node.exe` and `node_modules` directly inside each version directory.
Windows' bundled `curl.exe` and `tar.exe` must be on PATH. `nvm exec` handles
`npm` and `npx` through their JavaScript entrypoints. Other commands use Zig's
Windows process launcher; batch files use Windows shell semantics. Prefer
explicit `.exe` commands when arguments must remain literal.

For the registry CLI, copy rather than symlink the binary:

```powershell
Copy-Item ./zig-out/bin/znvm.exe ./zig-out/bin/nrm.exe
./zig-out/bin/nrm.exe ls
```

Run `zig build test` and `./scripts/windows-smoke.ps1` for native validation.
The smoke test uses a disposable data root and restores its process environment.
Mirror-generated `binaries.env` remains POSIX shell syntax and is not sourced
by PowerShell yet; direct registry configuration and Node mirror selection
remain available. Use explicit commands rather than interactive menus.
