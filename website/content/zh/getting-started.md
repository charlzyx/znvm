# 快速开始

**znvm** — **零负担 Node 版本管理器**

基于 Zig 的 **Node.js 版本管理器**。安装之后有两个命令：`nvm` 和 `nrm`。版本放在 `$NVM_DIR/versions/node`（默认 `~/.nvm`）。默认下载镜像是 npmmirror。2026-10-22 测得暖 shell 启动 **3.31 ms**，冷 shell 启动 **5.01 ms**（见首页表格）。

在终端里不带参数运行 `nvm` 会打开交互引导（`nvm guide` 相同）。没有终端时，它只打印一句说明并退出。

## 给 Agent

不额外安装就能学会 znvm，直接问二进制：

```bash
nvm --llm
nrm --llm
```

两条命令都把 `skills/znvm/SKILL.md` 打到 stdout 然后退出。二进制在编译时嵌入这个文件，所以命令输出和文件一致。

```bash
npx skills add charlzyx/znvm
```

如果当前客户端不能安装技能，就把 `skills/znvm/SKILL.md` 复制到它的技能目录。

没有 MCP 服务。`nvm` 和 `nrm` 已经是 shell 命令。MCP 服务只会再包一层同一个二进制。

`nvm` 管 Node 版本。`nrm` 管 npm 源和 `@scope`。`nvm mirror` 管 Electron、Playwright 这些工具的下载地址。`nvm install` 和 `nvm use` 不带版本时先读 `.nvmrc`，没有再读 `.node-version`。

`--json` 给 `nvm ls`、`nvm ls-remote`（含 `--lts`）、`nvm current`、`nvm which`、`nvm version`、`nvm --version`、`nrm ls`、`nrm current`、`nrm test`、`nrm scope ls`、`nvm mirror ls` 和 `nvm mirror test` 在 stdout 打一个 JSON 对象。错误是 stderr 上的 `{"error":"...","exit":N}`。stdout 为空，退出码与文本模式相同：0 成功，1 用法或失败，3 没有匹配版本，8 别名循环，55 不支持的选项，127 找不到系统 node 或版本文件。

已安装 v18.0.0 和 v20.11.0、别名 `default -> 18`、PATH 上没有 Node 时，`nvm ls --json` 打印：

```json
{"current":null,"versions":[{"version":"v18.0.0","current":false},{"version":"v20.11.0","current":false}],"aliases":[{"name":"default","target":"18"}]}
```

菜单只在 stdin 和菜单所在的输出都是终端时才出现。`--yes`、`NVM_NONINTERACTIVE=1`（`true` 和 `yes` 同样生效）以及非空的 `CI` 都会关掉菜单。`NO_COLOR` 保持纯 ASCII。`--guide-step` 把菜单画在 stderr。

找不到命令时：

```bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
```

## 安装

### 快速安装（推荐）

```bash
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

结束后会打印：

```text
nvm
Node versions go in ~/.nvm. Downloads use https://npmmirror.com/mirrors/node.

> Downloading nvm v2.7.0 (x86_64-linux)...
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

`source` 那一行是脚本实际改过的配置文件（`~/.bashrc`、`~/.zshrc` 或 `~/.profile`）。脚本可以重复执行。如果 `nvm --version` 已经是这一版，就保留现有二进制；如果版本不同，会把旧文件留作 `nvm.bak` 再替换。不会重复写入这段配置，也不会删除 `~/.nvm/versions/node` 里已有的 Node。

### 安装器做了什么

1. 检测平台（macOS/Linux）和架构（x64/arm64）
2. 安装 `nvm` 命令，把 `nrm` 链接到它，并写入 `~/.nvm/nvm.sh`
3. 把 `NVM_DIR` 的启动行追加到 shell 配置
4. 保留 `$NVM_DIR/versions/node` 里已经装好的 Node 版本

`nrm` 是和 `nvm` 同目录的相对符号链接。如果那个路径已经有文件，安装器会保留它并打印说明。如果 `PATH` 上还有另一个 `nrm`，会打印那个路径，不会删除它。新的 shell 会把 `nvm` 所在目录移到 `PATH` 最前面，因此这个 `nrm` 先运行。`install-as-nvm.sh --uninstall` 会删除 `nvm` 二进制和指向它的 `nrm` 链接，恢复或去掉 shell 配置段，不会删除 Node 版本，也不会删除别人的 `nrm`。

### Shell 配置

安装器写入：

```bash
# nvm: shell setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

新开一个终端，或 `source` 那个配置文件。之后的命令是 `nvm` 和 `nrm`。

## 交互引导

```bash
nvm
```

菜单用数字加回车。安装、切换、列出和卸载都会执行下面这些 `nvm` 命令。同一菜单里还有镜像源(scope)和下载镜像。`LC_ALL`、`LC_MESSAGES` 或 `LANG` 以 `zh` 开头时用中文提示。

## 镜像源

`nvm registry` 保存一个默认源和任意多个 `@scope` 路由，并写给 npm、yarn、pnpm 和 bun。交互菜单可以查看这张表、添加或修改 scope、删除 scope、设置默认源、同步全部文件、切到中国默认源并保留 scope，或恢复官方 npm 源。

```bash
nvm registry show
nvm registry set-default https://registry.npmmirror.com
nvm registry add @company https://npm.company.example
nvm registry remove @company
nvm registry china
nvm registry official
nvm registry sync
```

`china` 把默认源设为 `https://registry.npmmirror.com`。`official` 把默认源设为 `https://registry.npmjs.org`。两种情况下 scope 都保留。映射在 `$NVM_DIR/registries.json`。同步会更新 `~/.npmrc`、`~/.yarnrc`、`~/.yarnrc.yml`、pnpm 的 rc 和 `~/.bunfig.toml`。这些文件里的其他设置会留下。下载镜像是 `nvm mirror`，同步源不会改掉它们。

## nrm

`nrm` 是同一个二进制，由命令名决定。`nvm use`、`nvm ls` 和 `nvm current` 只选 Node 版本。`nrm use`、`nrm ls` 和 `nvm current` 才选源。在终端里不带参数运行 `nrm` 会打开菜单，里面有源、scope 和测速。没有终端时打印帮助。`nvm.sh` 里的 shell 函数只包住 `nvm`。下载镜像是 `nvm mirror`。

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

内置名字是 `npm`、`yarn`、`tencent`、`cnpm`、`taobao`、`npmMirror` 和 `huawei`。`nrm use taobao` 和 `nvm registry china` 指向同一个 npmmirror 地址。末尾一个斜杠不影响匹配。`nrm del` 不能删除内置名字。`nrm use auto` 写入最快且有响应的源，不改 `@scope`。`nrm test` 每次都会重新测量。结果保留 6 小时。`nvm registry` 仍然可用。

## 下载镜像

```bash
nvm mirror ls
nvm mirror use china
nvm mirror use official
nvm mirror use auto
nvm mirror set electron https://cdn.npmmirror.com/binaries/electron/
nvm mirror reset
nvm mirror test
```

`china` 写入 npmmirror 的下载地址（Electron、electron-builder、Playwright、Cypress、puppeteer、sharp、libvips、node-sass，以及其他常见项），也包括 Node 发行包镜像。`official` 清掉它们。`auto` 为每个工具留下更快的一边。npm、pnpm 和 yarn v1 的键写进各自的 rc。只认环境变量的值写在 `$NVM_DIR/binaries.env`，新的 shell 会通过 `nvm.sh` source 它。`reset` 只删掉这个文件和 `# nvm binaries` 段。scope 保持不动。安装时不会测量。

清掉 Node 镜像之后，下载回到 znvm 自己的默认地址。要强制用 nodejs.org，运行 `nvm mirror set node https://nodejs.org/dist`。

这里不设置 Docker 镜像。把 Docker daemon 指到镜像需要改特权配置并重启 daemon。

## 使用

### 安装 Node.js

用 `22` 获取最新的 v22.x.x：

```bash
nvm install 22            # 最新的 v22.x.x
nvm install --lts         # 最新 LTS
nvm install 20.11.0       # 特定版本
nvm install v18.20.0      # 带 v 前缀
nvm install               # 读取 .nvmrc 并安装，然后切换过去
```

### 切换版本

```bash
nvm use 20                # 切换到 Node 20
nvm use                   # 从当前目录或父目录的 .nvmrc 读取
nvm use --lts
```

### 列出已安装版本

```bash
nvm ls
nvm current
nvm which 20
```

`->` 标出当前版本。别名列在版本后面。

### 设置默认版本

```bash
nvm alias default 20      # 与 nvm default 20 相同
nvm alias
```

进入没有 `.nvmrc`、也没有 `.node-version` 的目录时，会用 `default` 别名。

### 卸载版本

```bash
nvm uninstall 20
nvm deactivate
```

## 使用 .nvmrc 自动切换

加载了 `nvm.sh` 之后，进入目录会读取 `.nvmrc` 并切换到已安装的版本。当前目录往上都不存在 `.nvmrc` 时，才读 `.node-version`。缺少的版本不会自动下载。

```bash
echo "20" > .nvmrc
cd /my-project
```

## 环境变量

| 变量 | 描述 | 默认值 |
|------|------|--------|
| `NVM_DIR` | Node 版本根目录（`versions/node`） | `~/.nvm` |
| `NVM_NODEJS_ORG_MIRROR` | 覆盖 Node.js 下载镜像 | 未设置；下载使用 `https://npmmirror.com/mirrors/node` |

```bash
export NVM_DIR="$HOME/.nvm"
export NVM_NODEJS_ORG_MIRROR=https://nodejs.org/dist
```

## 全局包

`npm install -g` 装到当前 Node 版本里。`nvm reinstall-packages <version>` 把该版本的全局包复制到当前版本。

## 命令

| 命令 | 描述 |
|------|------|
| `nvm install [version]` | 安装 Node.js 版本 |
| `nvm use [version]` | 切换版本，或读取 `.nvmrc` |
| `nvm ls` | 列出已安装版本 |
| `nvm alias default [version]` | 设置或显示默认别名 |
| `nvm uninstall <version>` | 移除版本 |
| `nvm version` | 当前 Node 版本（这个 nvm 没有提供 Node 时是 `none` 或 `system`） |
| `nvm --version` | 已安装工具的版本 |
| `nvm mirror` | Node 发行包地址和下载镜像 |
| `nrm` | 源、scope、测速和自动选择 |

## 故障排除

### 找不到 `nvm`

新开一个终端，或加载安装器打印的配置：

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

### 安装后版本未找到

```bash
nvm use 22
```

### 自动切换不工作

确认配置里仍有上面的 `NVM_DIR` / `nvm.sh` 两行。要停用自动切换，删掉这两行。

---

**相关：** [为什么构建 znvm](/zh/blog/why-zig) | [GitHub](https://github.com/charlzyx/znvm)
