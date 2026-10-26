---
title: Windows 安装
description: 下载、解压，选一个终端开始使用 Node。
---

## 1. 下载
[Windows x64（Intel / AMD）](https://github.com/charlzyx/znvm/releases/download/v2.10.0/znvm-v2.10.0-x86_64-windows.zip) · [Windows ARM64](https://github.com/charlzyx/znvm/releases/download/v2.10.0/znvm-v2.10.0-aarch64-windows.zip) · [校验文件](https://github.com/charlzyx/znvm/releases/download/v2.10.0/SHA256SUMS)

## 2. 解压
解压到自己的目录，保留 `bin` 和 `cmd` 文件夹的相对位置。在解压后的包根目录打开终端，不要进入 `bin`。

## 3. 选择终端
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

初始化只对当前终端生效，新开终端时再执行一次。用 `nvm deactivate` 退出当前版本。

[兼容性与使用限制](https://github.com/charlzyx/znvm/blob/v2.10.0/WINDOWS.md)
