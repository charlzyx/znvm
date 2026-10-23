# znvm (Zig Node Version Manager)

**基于 Zig 的 Node.js 版本管理器。日常命令对齐 nvm，版本放在 `~/.nvm`，下载默认走 npmmirror。**

[![GitHub stars](https://img.shields.io/github/stars/charlzyx/znvm.svg?style=social)](https://github.com/charlzyx/znvm)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Language: Zig](https://img.shields.io/badge/Language-Zig-f7a41d.svg)](https://ziglang.org/)

---

## 🚀 为什么选择 znvm?

**znvm** 是面向日常 nvm 用法的 Zig 版 Node.js 版本管理器。默认下载镜像是 npmmirror。下面的性能对比是实测，不是口号。

- **实测启动**: 2026-10-22，暖 shell 启动中位数是 znvm **3.31 ms**、fnm **1.58 ms**、nvm **113 ms**。每次丢掉页缓存后，中位数是 **5.01 ms**、**4.70 ms**、**121 ms**。p95 和 shell 内命令见下面的性能对比。
- **零配置**: 完美支持 `.nvmrc`。只需 `cd` 进入目录，环境立即就绪。
- **极简专注**: 无冗余依赖，无 Windows 平台的沉重抽象。纯粹为 Unix 性能而生。
- **智能架构**: Zig 核心处理复杂的 SemVer 解析；Shell 脚本负责环境切换。

## 📦 快速安装

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

`https://znvm.dev/install-as-nvm.sh` 是同一个脚本。

脚本会安装 `nvm` 命令，把 `nrm` 链接到同一个二进制，并写入 `~/.nvm/nvm.sh`。可以重复执行。如果 `nvm --version` 已经是这一版，就保留现有二进制；如果版本不同，会把旧文件留作 `nvm.bak` 再替换，并打印 `ok Upgraded nvm vX -> vY`。不会重复写入 shell 配置，也不会删除 `~/.nvm/versions/node` 里已有的 Node。不会安装 shell 补全。

`nrm` 是 `nvm` 旁边的相对符号链接。安装脚本不会覆盖已经存在的 `nrm`。如果那个路径上已有文件，会打印说明并保留它。如果 `PATH` 上还有另一个 `nrm`，会打印那个路径，不会删除它。新的 shell 会把 `nvm` 所在目录移到 `PATH` 最前面，因此链接的 `nrm` 先被找到。`--uninstall` 会删除这次安装的 `nvm` 二进制，以及指向它的 `nrm` 链接；如果有 `nvm.sh.bak` 就恢复 `nvm.sh`；去掉 `nvm: shell setup` 那段配置。不会删除 Node 版本，也不会删除别人的 `nrm`。

结束后会打印：

```text
nvm is ready.

Open a new terminal, or run:
  source "~/.bashrc"

export NVM_DIR="$HOME/.nvm"
nvm install 22
nvm use 22
nvm ls
nrm ls

Node versions are stored in $NVM_DIR/versions/node.
Downloads use https://npmmirror.com/mirrors/node unless NVM_NODEJS_ORG_MIRROR is set.
```

`source` 那一行里的路径是脚本实际改过的配置文件。

### 安装指定版本

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/v2.2.2/install-as-nvm.sh | bash
```

## ✨ 核心特性

- ⚡ **性能巅峰**: 核心逻辑由 Zig 编写，版本解析瞬间完成。
- 🍎 **Apple Silicon 友好**: 自动检测架构，支持 Node.js 旧版本的 Rosetta 自动回退。
- 🐧 **Unix 原生**: 深度适配 macOS 和 Linux。
- 🔄 **自动切换**: 进入包含 `.nvmrc` 的目录时自动切换 Node 版本。
- 📦 **按版本隔离的全局包**: 与 nvm 一样，全局 npm 包留在各自的 Node 版本里。

## 🛠 使用方法

```bash
# 安装。`node` 是最新正式版，`lts/*` 是最新 LTS。
nvm install 22
nvm install --lts
nvm install             # 读取 .nvmrc 并安装，然后切换过去

# 切换。不带版本时从当前目录或父目录的 .nvmrc 读取。
nvm use 20
nvm use
nvm use --lts

nvm current
nvm which 20
nvm ls                  # -> 表示当前版本，并列出别名
nvm ls-remote --lts

nvm alias default 20    # 与 nvm default 20 相同
nvm run 20 --version
nvm exec 20 npm test
nvm uninstall 20
```

在终端里不带参数运行 `nvm` 会打开交互引导。`nvm guide` 和 `nvm interactive` 是同一个菜单。没有终端时，`nvm` 只打印一句说明并退出。同一个菜单可以改包的源：多个 `@scope` 同时指向不同仓库，默认源单独设置，然后同步到 npm、yarn、pnpm 和 bun。

```bash
nvm registry add @company https://npm.company.example
nvm registry china          # 默认源改为 https://registry.npmmirror.com，scope 保留
nvm registry official       # 默认源改为 https://registry.npmjs.org，scope 保留
nvm registry show
```

映射保存在 `$NVM_DIR/registries.json`。同步会改写 `~/.npmrc`、`~/.yarnrc`、`~/.yarnrc.yml`、pnpm 的 rc（Linux 是 `~/.config/pnpm/rc`，macOS 是 `~/Library/Preferences/pnpm/rc`）和 `~/.bunfig.toml` 里的默认源和 `@scope` 源。这些文件里的其他行会留下。`~/.yarnrc.yml` 里的 `npmScopes` 段会按已保存的 scope 重写。下载镜像是 `nvm mirror`，同步源不会改掉它们。

同一次安装也提供 `nrm`。命令名是 `nrm` 时，运行的是同一个二进制。`nvm use`、`nvm ls` 和 `nvm current` 只选 Node 版本。`nrm use`、`nrm ls` 和 `nrm current` 才选源。`nvm registry` 是这张表的带前缀别名。

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

内置名字是 `npm`、`yarn`、`tencent`、`cnpm`、`taobao`、`npmMirror` 和 `huawei`。`nrm use` 以及 `nvm registry china` / `official` 会在地址匹配时选中内置名字，末尾一个斜杠忽略。`nrm del` 不能删除内置名字。`nrm use auto` 测量各个源，并写入最快且可用的那个。它不改 `@scope`。`nrm test` 每次都会重新测量。结果在 `$NVM_DIR/mirror-latency.json` 里保留 6 小时。在终端里不带参数运行 `nrm` 会打开菜单，里面有源、scope 和测速。没有终端时打印帮助。`nrm add` 可以多带一个 home 参数，会被忽略。`nrm` 不接受 `binary` 或 `mirror`。

`nvm mirror` 把 Node 发行包地址和工具真正读取的下载地址写出去。交互引导里对应的一项是「下载镜像」。

```bash
nvm mirror ls
nvm mirror use china
nvm mirror use auto
nvm mirror set electron https://cdn.npmmirror.com/binaries/electron/
nvm mirror reset
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

`official` 清掉这些地址。`set` 只改一个 URL。`auto` 把每个中国镜像和对应的上游地址比一次，留下更快的那边。npm、pnpm 和 yarn v1 的键写在各自的 rc 里，包在 `# nvm binaries` 段中。只认环境变量的值写在 `$NVM_DIR/binaries.env`，`nvm.sh` 会 source 它。`reset` 删掉这个文件和这段配置，源、scope 和其他设置留下。清掉 Node 镜像之后，下载回到 znvm 自己的默认地址。要强制用 nodejs.org，运行 `nvm mirror set node https://nodejs.org/dist`。安装时不会测量。

这里不设置 Docker 镜像。把 Docker daemon 指到镜像需要改特权配置并重启 daemon，留到以后再做。

版本目录与 nvm 相同：`$NVM_DIR/versions/node`（默认 `~/.nvm`），已经装好的版本可以直接用。0.12 之前的 Node 从 `$NVM_DIR/vX.Y.Z` 读取。

默认下载镜像是 `https://npmmirror.com/mirrors/node`。要换镜像，设置 `NVM_NODEJS_ORG_MIRROR`。

`nvm version` 打印当前 Node 版本（这个 nvm 没有提供 Node 时是 `none` 或 `system`）。`nvm --version` 打印已安装工具的版本。

没有 `nvm completion` 命令，安装脚本也不会加入 shell 补全。

进入目录时会根据 `.nvmrc` 切换已安装的版本，找不到 `.nvmrc` 时再读 `.node-version`，都不会自动下载。全局包跟 nvm 一样放在各个 Node 版本里；`reinstall-packages` 和 `--reinstall-packages-from` 会把它们复制到要切换到的版本。

不做源码编译（`-s`，只安装官方二进制）、io.js / `unstable`（已停止维护，不在 Node 镜像上）和 `set-colors`（只影响终端颜色）。`nvm ls` 输出纯文本。Docker 镜像也不在这里设置。`nvm mirror` 管的是工具下载地址，Docker daemon 是另一份需要特权的配置。

## ⚙️ Shell 配置

`install-as-nvm.sh` 会把下面几行追加到它更新的 shell 配置（`~/.bashrc`、`~/.zshrc` 或 `~/.profile`）：

```bash
# nvm: shell setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

新开一个终端，或 `source` 那个配置文件。之后的命令是 `nvm`。版本在 `$NVM_DIR/versions/node`。

## 给 Agent

直接跑命令。没有 MCP 服务。不额外安装就能读到用法：

```bash
nvm --llm
nrm --llm
```

两条命令都打印 [`skills/znvm/SKILL.md`](skills/znvm/SKILL.md)。二进制在编译时嵌入这个文件。同一段文字在 [llm.txt](https://znvm.dev/llm.txt)（`/llms.txt` 是别名）。

```bash
npx skills add charlzyx/znvm
```

这条命令安装 `skills/znvm/SKILL.md`。客户端不能安装技能时，复制这个文件。

`nvm` 管 Node 版本。`nrm` 管 npm 源和 `@scope`。`nvm mirror` 管上表里的每一个下载地址。`nvm install` 和 `nvm use` 不带版本时先读 `.nvmrc`，没有再读 `.node-version`。

菜单只在 stdin 和菜单所在的输出都是终端、`CI` 为空、并且没有 `--yes` 或 `NVM_NONINTERACTIVE=1`（`true` 和 `yes` 同样生效）时才出现。`NO_COLOR` 保持纯 ASCII。`--guide-step` 把菜单画在 stderr。

`--json` 给 `ls`、`ls-remote`、`current`、`which`、`version`、`--version`、`nrm ls`、`nrm current`、`nrm test`、`nrm scope ls`、`nvm mirror ls` 和 `nvm mirror test` 在 stdout 打一个 JSON 对象。错误是 stderr 上的 `{"error":"...","exit":N}`，stdout 为空，退出码与文本模式相同：0 成功，1 用法或失败，3 没有匹配版本，8 别名循环，55 不支持的选项，127 找不到系统 node 或版本文件。引导菜单退出是 2。

已安装 v18.0.0 和 v20.11.0、别名 `default -> 18`、PATH 上没有 Node 时，`nvm ls --json` 是：

```json
{"current":null,"versions":[{"version":"v18.0.0","current":false},{"version":"v20.11.0","current":false}],"aliases":[{"name":"default","target":"18"}]}
```

`current` 是当前版本、`"system"` 或 `null`。带版本过滤或 `--no-alias` 时 `aliases` 为空。其余字段见 [`skills/znvm/SKILL.md`](skills/znvm/SKILL.md)。

找不到命令时：`export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"`。新的 shell 还会 source `$NVM_DIR/binaries.env`。

## 📊 性能对比

下面是 **2026-10-22 15:38:50Z–15:40:25Z** 同一次运行里的暖启动和冷启动中位数，脚本是 [`benchmarks/measure.py`](benchmarks/measure.py)。环境：4 核 KVM 虚拟机，lscpu 型号为 `Intel(R) Xeon(R) Processor`，Ubuntu 24.04.5。znvm 是 ReleaseSafe，3,910,296 字节（3.73 MiB，未 strip）。对照 nvm v0.40.3（`nvm.sh` 150,227 字节）和 fnm 1.39.0（7,374,576 字节）。已安装 v22.14.0（默认）和 v20.19.0。PATH 只有工具目录加 `/usr/bin:/bin`。原始样本：[`benchmarks/results/2026-10-22-cold-warm.json`](benchmarks/results/2026-10-22-cold-warm.json)。

shell 启动是新的 `bash --noprofile --norc` 执行文档化 init，再减去同样方式测得的 `bash -c true`。暖：预热 5 次、采样 20 次，页缓存保持热（基线中位数 0.63 ms）。冷：20 次，不丢弃预热，每次包括基线都先 `sync` 并丢掉页缓存（基线中位数 2.02 ms，p95 3.91 ms）。每个冷样本序号里三个工具轮流测。fnm 的文档化 init 当时已经是 Node v22.14.0。暖运行里多一次 `fnm use` 是 2.50 ms（p95 2.80 ms），不是表中的数字。以这次的样本量，插值 p50 等于中位数。

| 管理器 | 暖中位数 | 暖 p95 | 冷中位数 | 冷 p95 |
| :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 115 ms | 121 ms | 128 ms |
| `fnm` | 1.58 ms | 1.76 ms | 4.70 ms | 6.67 ms |
| **`znvm`** | **3.31 ms** | **3.64 ms** | **5.01 ms** | **9.28 ms** |

下面的 `list` / `use` / `.nvmrc` 在已经初始化的 shell 里。暖：预热 10 次、采样 40 次，减去 shell 内 `true`（约 0.04 ms）。冷：20 次，每次命令前丢掉页缓存，shell 进程保留；减去该工具冷的 shell 内 `true`（0.20–0.26 ms）。`use` 在 v20.19.0 和 v22.14.0 之间交替。`.nvmrc` 的内容是 `20.19.0`。

| 管理器 | list 暖 | list 冷 | use 暖 | use 冷 | .nvmrc 暖 | .nvmrc 冷 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 559 ms | 557 ms | 158 ms | 221 ms | 166 ms | 222 ms |
| `fnm` | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms | 1.41 ms | 5.20 ms |
| **`znvm`** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** | **0.86 ms** | **3.06 ms** |

暖命令 p95：nvm 587 / 165 / 170 ms，fnm 1.63 / 1.70 / 1.87 ms，znvm 0.87 / 1.21 / 1.33 ms。冷命令 p95：nvm 570 / 246 / 244 ms，fnm 8.70 / 8.80 / 7.61 ms，znvm 5.03 / 7.36 / 4.69 ms（list / use / .nvmrc）。

这次暖、冷 shell 启动都是 fnm 低于 znvm，两者都低于 nvm。暖、冷的 shell 内命令都是 znvm 更低。znvm 冷启动的 p95（9.28 ms）比中位数散。

体积：znvm 3.73 MiB，fnm 7.03 MiB，nvm 146.7 KiB 脚本。

这次没有重跑安装。更早的 3 次安装（含下载）仍在 [`benchmarks/results/2026-10-22.json`](benchmarks/results/2026-10-22.json)：znvm 1241 ms，fnm 2317 ms，nvm 2327 ms。那个文件里的暖表和单次冷样本是更早的一次运行，上面的表替换它们。安装耗时主要是网络。

`benchmarks/benchmark_key_operations.sh` 已停用。它只采一次 `time`，只在 nvm 的计时里 `source nvm.sh`，并且调用了不存在的 `znvm resolve`。

## 📖 官方文档

完整文档请访问 [znvm.dev](https://znvm.dev) (即将上线！)。

## 🏗 本地开发

```bash
zig build -Doptimize=ReleaseSafe
```

## 📄 开源协议

MIT
