---
title: Windows 安装
description: 原生 Windows x64 和 ARM64，支持 PowerShell 7、cmd 与 Git Bash。
---

## 下载 v2.10.0

先在 **Windows 设置 → 系统 → 系统信息 → 系统类型** 中确认架构。从同一个官方 Release 下载 ZIP 和校验列表：

| Windows 设备 | 下载包 |
| --- | --- |
| Intel / AMD，x64 | [下载 x64 ZIP](https://github.com/charlzyx/znvm/releases/download/v2.10.0/znvm-v2.10.0-x86_64-windows.zip) |
| ARM64 | [下载 ARM64 ZIP](https://github.com/charlzyx/znvm/releases/download/v2.10.0/znvm-v2.10.0-aarch64-windows.zip) |

[SHA256SUMS](https://github.com/charlzyx/znvm/releases/download/v2.10.0/SHA256SUMS) · [发布说明](https://github.com/charlzyx/znvm/releases/tag/v2.10.0)

在下载目录运行以下命令，把哈希与 `SHA256SUMS` 中**对应 ZIP 文件名**的那一行比较。ARM64 请将 `x86_64` 换成 `aarch64`：

```powershell
Get-FileHash .\znvm-v2.10.0-x86_64-windows.zip -Algorithm SHA256
Get-Content .\SHA256SUMS
```

不一致就停止使用。校验和用于检查文件完整性，不能独立证明发布者身份；请从上面的官方 Release 获取两个文件。

解压到**自己有写入权限的目录**，然后在包根目录打开终端。保留完整目录结构：真正的 `bin/nvm.exe`、`bin/nrm.exe`，以及包含 `init.cmd`、`nvm.cmd`、`finish.cmd` 的独立 `cmd` 目录。不要把二进制和包装脚本移开，也不要进入 `bin` 目录初始化 cmd。

无需管理员权限、开发者模式、符号链接或 junction。初始化只修改当前终端，不写入配置文件或永久/系统 PATH。新开终端需要重新初始化。PATH 中需有 Windows 自带的 `curl.exe`。

## PowerShell 7

在包根目录执行：

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

仅执行可信二进制生成的初始化代码。后续切换采用固定白名单数据格式，不执行任意输出。`nvm exec 22 npm` 和 `npx` 直接调用 JavaScript 入口，不额外经过 cmd 解析。

## cmd：关闭延迟展开

在包根目录打开关闭延迟展开的 cmd，再初始化：

```bat
cmd /V:OFF
cmd\init.cmd
nvm install 22
nvm use 22
node --version
nrm ls
nvm deactivate
```

在其他批处理文件中使用 `call "C:\path to package\cmd\init.cmd"` 和 `call nvm ...`。初始化把独立的包装脚本目录放在当前终端 PATH 的 `bin` 前面。直接运行 `nvm.exe` 不能修改父 shell；请使用初始化后的 `nvm`，必要时明确调用 `nvm.cmd`。

为保护含 `!` 的路径，`/V:ON` 会被拒绝。直接输入的路径若含 `%`，仍需遵守 cmd 的展开与转义规则。环境更新会短暂切换 UTF-8 控制台代码页，随后恢复，不修改系统设置。超长或含换行的环境更新会被拒绝。

## Git Bash

在包根目录执行：

```bash
setup=$(./bin/nvm.exe env --shell bash) && eval "$setup"
nvm install 22
nvm use 22
node --version
./bin/nrm.exe ls
nvm deactivate
```

包装函数使用 Git Bash 自带的 `cygpath` 和 `base64`。只有初始化使用 `eval`；切换响应是白名单 Base64 数据。原生进程参数按字面传递，关闭 MSYS 自动参数转换。

对于 `nvm run` 和 `nvm exec … node` / `node.exe`，第一个脚本参数，或 Node 的 `--` 后紧接的参数，若是实际存在的普通文件，会从 POSIX 路径转换为 Windows 路径。别名和隐式 `.nvmrc` 选择同样适用。`-e` / `-p` 中的 JavaScript 与脚本后面的参数保持原样。若脚本前还有其他 Node 选项，请用 `cygpath -w` 手动转换脚本路径；其他原生命令同样需要 Windows 格式路径。

**ARM64 验证边界：**已在 Windows ARM64 上验证原生 ARM64 的 nvm 和 Node 进程。托管 runner 的 Git 启动器是 ARM64，但 `usr/bin/bash.exe` 运行时是通过 Windows 模拟运行的 x64。这不代表 Bash 运行时本身是原生 ARM64。

## 存储与支持边界

- `NVM_DIR` 可覆盖数据根目录；未设置时使用 `HOME`，再回退到 `USERPROFILE` 下的 `.nvm`。版本位于 `versions/node`，每个版本目录直接包含 `node.exe` 和 `node_modules`。
- 支持 `install`、`use`、`ls`、`current`、`which`、`run`、`exec`、别名、`uninstall` 和 `deactivate`。`nvm use` 可以读取 `.nvmrc`；Windows 暂不支持进入目录自动切换或方向键交互菜单。
- 不导入已有 nvm-windows 的符号链接安装。这是 znvm 的 nvm 兼容 CLI，不是另一个 nvm-windows 项目。
- 可使用 registry 命令和 Node 下载镜像配置。镜像生成的 `binaries.env` 仍为 POSIX 语法，PowerShell 不会加载。参数需要保持字面值时优先调用明确的 `.exe`；批处理文件遵循 Windows shell 语义。
- `nvm uninstall 22` 删除该版本，并在它处于激活状态时停用当前 shell。单独执行 `nvm deactivate` 不删除已安装版本。

[完整命令](/zh/getting-started) · [源码与验证说明](https://github.com/charlzyx/znvm/blob/v2.10.0/WINDOWS.md)
