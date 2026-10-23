# 快速开始

Zig 写的 NVM 和 NRM。版本在 `$NVM_DIR/versions/node`（默认 `~/.nvm`）。下载走 npmmirror。2026-10-22：热启动 3.31 ms，冷启动 5.01 ms。

直接敲 `nvm` 打开引导。没有终端就只打一行，然后退出。

## 安装

### 安装命令

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

`https://znvm.dev/install-as-nvm.sh` 是同一个脚本。

结束后会打印：

```text
nvm
Node versions go in ~/.nvm. Downloads use https://npmmirror.com/mirrors/node.

> Downloading nvm v2.8.2 (x86_64-linux)...
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

`source` 脚本打印的配置（`~/.bashrc`、`~/.zshrc` 或 `~/.profile`）。可以重复执行。`nvm --version` 已是这一版就保留二进制。版本不同则把旧文件留作 `nvm.bak` 再替换。不重复写入配置，不删除已有 Node。

### 安装器做了什么

1. 检测平台（macOS/Linux）和架构（x64/arm64）
2. 安装 `nvm` 命令，把 `nrm` 链接到它，并写入 `~/.nvm/nvm.sh`
3. 把 `NVM_DIR` 的启动行追加到 shell 配置
4. 保留 `$NVM_DIR/versions/node` 里已经装好的 Node 版本

`nrm` 是 `nvm` 旁边的相对符号链接。已有文件会留下。`PATH` 上别人的 `nrm` 也会留下。新 shell 把这个目录放在最前。`--uninstall` 删除 `nvm`、指向它的 `nrm` 链接和 shell 配置段。不删除 Node，也不删除别人的 `nrm`。

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

上下键选择，回车确认。数字仍然可用。菜单里有源和下载镜像。`LC_ALL`、`LC_MESSAGES` 或 `LANG` 以 `zh` 开头时用中文。

## 镜像源

一个默认源，加上任意多个 `@scope`，写给 npm、yarn、pnpm 和 bun。

```bash
nvm registry show
nvm registry set-default https://registry.npmmirror.com
nvm registry add @company https://npm.company.example
nvm registry remove @company
nvm registry china
nvm registry official
nvm registry sync
```

`china` 设为 `https://registry.npmmirror.com`。`official` 设为 `https://registry.npmjs.org`。scope 保留。映射在 `$NVM_DIR/registries.json`。同步写入 `~/.npmrc`、`~/.yarnrc`、`~/.yarnrc.yml`、pnpm 的 rc 和 `~/.bunfig.toml`，留下其他设置和 `nvm mirror` 的地址。

## nrm

`nrm` 是同一个二进制的另一个名字。`nvm use`、`ls`、`current` 管 Node。`nrm use`、`ls`、`current` 管源。没有终端时 `nrm` 打印帮助。`nvm.sh` 只包 `nvm`。

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

内置：`npm`、`yarn`、`tencent`、`cnpm`、`taobao`、`npmMirror`、`huawei`。`nrm use taobao` 和 `nvm registry china` 是同一个地址。末尾一个斜杠仍算匹配。`nrm del` 不删内置名。`nrm use auto` 写入最快的源，不改 scope。`nrm test` 每次重测。结果保留 6 小时。

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

`nvm mirror ls` 列出每一个支持的名字。`china` 写入这些地址。

| 名字 | 覆盖 | 环境变量 / npmrc |
| --- | --- | --- |
| electron | Electron | `ELECTRON_MIRROR`，npmrc `electron_mirror` |
| electron-builder | electron-builder 二进制 | `ELECTRON_BUILDER_BINARIES_MIRROR`，npmrc `electron_builder_binaries_mirror` |
| playwright | Chromium、Firefox、WebKit 浏览器下载 | `PLAYWRIGHT_DOWNLOAD_HOST` |
| cypress | Cypress 压缩包 | `CYPRESS_DOWNLOAD_PATH_TEMPLATE` |
| puppeteer | Chrome for Testing 和 chrome-headless-shell | `PUPPETEER_DOWNLOAD_HOST`、`PUPPETEER_DOWNLOAD_BASE_URL`、`PUPPETEER_CHROME_DOWNLOAD_BASE_URL`、`PUPPETEER_CHROME_HEADLESS_SHELL_DOWNLOAD_BASE_URL` |
| node-sass | node-sass | `SASS_BINARY_SITE`，npmrc `sass_binary_site` |
| sharp | sharp 预编译包 | `npm_config_sharp_binary_host`，npmrc `sharp_binary_host` |
| libvips | sharp 用的 libvips | `npm_config_sharp_libvips_binary_host`，npmrc `sharp_libvips_binary_host` |
| node | Node 发行包 | `NODEJS_ORG_MIRROR`、`NVM_NODEJS_ORG_MIRROR` |
| chromedriver | ChromeDriver | `CHROMEDRIVER_CDNURL` |
| edgedriver | EdgeDriver | `EDGEDRIVER_CDNURL` |
| operadriver | OperaDriver | `OPERADRIVER_CDNURL` |
| phantomjs | PhantomJS | `PHANTOMJS_CDNURL` |
| node-swc | SWC | `SWC_BINARY_SITE` |
| nwjs | NW.js | `NWJS_URLBASE` |
| sentry-cli | sentry-cli | `SENTRYCLI_CDNURL` |
| saucectl | saucectl | `SAUCECTL_INSTALL_BINARY_MIRROR` |
| node-re2 | node-re2 | `RE2_DOWNLOAD_MIRROR`、`RE2_DOWNLOAD_SKIP_PATH` |
| prisma | Prisma engines | `PRISMA_ENGINES_MIRROR` |
| better-sqlite3 | better-sqlite3 预编译包 | `npm_config_better_sqlite3_binary_host`，npmrc `better_sqlite3_binary_host` |
| isolated-vm | isolated-vm 预编译包 | `npm_config_isolated_vm_binary_host`，npmrc `isolated_vm_binary_host` |
| keytar | keytar 预编译包 | `npm_config_keytar_binary_host`，npmrc `keytar_binary_host` |
| robotjs | robotjs 预编译包 | `npm_config_robotjs_binary_host`，npmrc `robotjs_binary_host` |
| gl | headless-gl 预编译包 | `npm_config_gl_binary_host`，npmrc `gl_binary_host` |
| corepack | Corepack 的 npm registry | `COREPACK_NPM_REGISTRY` |
| ripgrep | ripgrep-prebuilt | `RIPGREP_PREBUILT_BINARIES_MIRROR` |
| sqlite3 | sqlite3 预编译包 | `npm_config_sqlite3_binary_host`，npmrc `sqlite3_binary_host` |
| canvas | node-canvas 预编译包 | `npm_config_canvas_binary_host`，npmrc `canvas_binary_host` |
| grpc | grpc 原生绑定（module `grpc_node`） | `npm_config_grpc_node_binary_host_mirror`，npmrc `grpc_node_binary_host_mirror` |
| grpc-tools | grpc-tools 二进制 | `npm_config_grpc_tools_binary_host_mirror`，npmrc `grpc_tools_binary_host_mirror` |
| nodejieba | nodejieba 预编译包 | `npm_config_nodejieba_binary_host_mirror`，npmrc `nodejieba_binary_host_mirror` |
| xprofiler | xprofiler 预编译包 | `npm_config_xprofiler_binary_host_mirror`，npmrc `xprofiler_binary_host_mirror` |
| gdal-async | node-gdal-async 预编译包（module `gdal`） | `npm_config_gdal_binary_host_mirror`，npmrc `gdal_binary_host_mirror` |
| ali-zeromq | zeromq 绑定（module `zmq`） | `npm_config_zmq_binary_host_mirror`，npmrc `zmq_binary_host_mirror` |
| ali-usb_ctl | usb_ctrl 绑定 | `npm_config_usb_ctrl_binary_host_mirror`，npmrc `usb_ctrl_binary_host_mirror` |

不设置。cnpm 要改包内文件（`replaceHost` / `replaceHostFiles`），配置项不能改下载地址：jpegtran-bin、cwebp-bin、zopflipng-bin、optipng-bin、mozjpeg、gifsicle、pngquant-bin、pngcrush-bin、jpeg-recompress-bin、advpng-bin、pngout-bin、jpegoptim-bin、flow-bin、@tensorflow/tfjs-node。

不设置。安装脚本没有可核对的 host 环境变量，或镜像路径和安装脚本对不上：@journeyapps/sqlcipher、leveldown、utf-8-validate、argon2、fsevents、couchbase、wrtc、skia-canvas、libpg-query、@ali/s2。

`official` 清掉。`auto` 为每个工具留下更快的一边。npm、pnpm、yarn v1 的键写入各自的 rc。环境变量写在 `$NVM_DIR/binaries.env`，由 `nvm.sh` source。`reset` 删掉这个文件和 `# nvm binaries` 段。scope 不动。安装时不测量。

清掉 Node 镜像后回到默认地址。强制 nodejs.org：`nvm mirror set node https://nodejs.org/dist`。

不设置 Docker。那要改 daemon 配置并重启。

## 使用

### 安装 Node.js

`22` 表示最新的 v22：

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

没有 `.nvmrc` 和 `.node-version` 时用 `default`。

### 卸载版本

```bash
nvm uninstall 20
nvm deactivate
```

## 使用 .nvmrc 自动切换

加载 `nvm.sh` 后，进入目录先读 `.nvmrc`，再读 `.node-version`。缺少的版本不会下载。

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

`npm install -g` 装进当前 Node。`nvm reinstall-packages <version>` 把该版本的全局包复制到当前版本。

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

**相关：** [为什么用 Zig](/zh/blog/why-zig) | [GitHub](https://github.com/charlzyx/znvm)
