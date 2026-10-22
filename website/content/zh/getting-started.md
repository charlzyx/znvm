# 快速开始

**znvm** — **零负担 Node 版本管理器**

基于 Zig 的 **Node.js 版本管理器**。安装之后的命令是 `nvm`。版本放在 `$NVM_DIR/versions/node`（默认 `~/.nvm`）。默认下载镜像是 npmmirror。2026-10-22 测得暖 shell 启动 **3.31 ms**，冷 shell 启动 **5.01 ms**（见首页表格）。

在终端里不带参数运行 `nvm` 会打开交互引导（`nvm guide` 相同）。没有终端时，它只打印一句说明并退出。

## 安装

### 快速安装（推荐）

```bash
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

结束后会打印：

```text
nvm is ready.

Open a new terminal, or run:
  source "~/.bashrc"

export NVM_DIR="$HOME/.nvm"
nvm install 22
nvm use 22
nvm ls

Node versions are stored in $NVM_DIR/versions/node.
Downloads use https://npmmirror.com/mirrors/node unless NVM_NODEJS_ORG_MIRROR is set.
```

`source` 那一行是脚本实际改过的配置文件（`~/.bashrc`、`~/.zshrc` 或 `~/.profile`）。脚本可以重复执行：不会重复写入这段配置，也不会删除 `~/.nvm/versions/node` 里已有的 Node。

### 安装器做了什么

1. 检测平台（macOS/Linux）和架构（x64/arm64）
2. 安装 `nvm` 命令并写入 `~/.nvm/nvm.sh`
3. 把 `NVM_DIR` 的启动行追加到 shell 配置
4. 保留 `$NVM_DIR/versions/node` 里已经装好的 Node 版本

### Shell 配置

安装器写入：

```bash
# nvm: shell setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

新开一个终端，或 `source` 那个配置文件。之后的命令是 `nvm`。

## 交互引导

```bash
nvm
```

菜单用数字加回车。安装、切换、列出和卸载都会执行下面这些 `nvm` 命令。`LC_ALL`、`LC_MESSAGES` 或 `LANG` 以 `zh` 开头时用中文提示。

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

`china` 把默认源设为 `https://registry.npmmirror.com`。`official` 把默认源设为 `https://registry.npmjs.org`。两种情况下 scope 都保留。映射在 `$NVM_DIR/registries.json`。同步会更新 `~/.npmrc`、`~/.yarnrc`、`~/.yarnrc.yml`、pnpm 的 rc 和 `~/.bunfig.toml`。这些文件里的其他设置会留下。Electron 和其他二进制镜像不会被改动。

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
