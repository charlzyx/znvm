---
title: Windows setup
description: Download, extract, and start using Node in your terminal.
---

## 1. Download
[Windows x64 (Intel / AMD)](https://github.com/charlzyx/znvm/releases/download/v2.10.0/znvm-v2.10.0-x86_64-windows.zip) · [Windows ARM64](https://github.com/charlzyx/znvm/releases/download/v2.10.0/znvm-v2.10.0-aarch64-windows.zip) · [Checksums](https://github.com/charlzyx/znvm/releases/download/v2.10.0/SHA256SUMS)

## 2. Extract
Extract into a folder you own. Keep the `bin` and `cmd` folders together, and open your terminal in the extracted package root—not inside `bin`.

## 3. Choose your terminal
### PowerShell 7
```powershell
$setup = & ./bin/nvm.exe env --shell powershell
if ($LASTEXITCODE -ne 0) { throw 'nvm initialization failed' }
Invoke-Expression ($setup -join "`n")
nvm install 22
nvm use 22
node --version
```

### cmd
```bat
cmd /V:OFF
cmd\init.cmd
nvm install 22
nvm use 22
node --version
```

### Git Bash
```bash
setup=$(./bin/nvm.exe env --shell bash) && eval "$setup"
nvm install 22
nvm use 22
node --version
```

Initialization applies only to this terminal; repeat it in each new terminal. Run `nvm deactivate` to stop using the selected version.

[Compatibility and limitations](https://github.com/charlzyx/znvm/blob/v2.10.0/WINDOWS.md)
