# Changelog

所有显著变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [v2.8.3] - 2026-10-23

### Added

- Install writes the china preset when the language is zh (`NVM_LANG=zh|en` first, then `LC_ALL` / `LC_MESSAGES` / `LANG`; `C`, `POSIX`, and `en` on macOS use `AppleLanguages` from `~/Library/Preferences/.GlobalPreferences.plist`). Anything else writes `https://registry.npmjs.org` and `https://nodejs.org/dist`, with no other binary hosts. `NVM_MIRROR=china|official` overrides that. An existing mirror config is kept. `nvm mirror use auto` and `nrm use auto` stay manual.
- Human-facing CLI text, including `nvm --help`, `nvm help <command>`, and `nrm --help`, is Chinese or English. `--json`, `--llm`, and machine-parsed lines stay English. `nvm lang` prints `zh` or `en`.

### Changed

- The long help notes now live in the README and `skills/znvm/SKILL.md`.

## [v2.8.2] - 2026-10-23

### Changed

- Built with Zig 0.17.0. Commands, exit codes, and text output stay the same.

## [v2.8.1] - 2026-10-23

### Added

- The interactive guide for `nvm` and `nrm` highlights a row. Up and Down, or k and j, move it. Enter confirms. Esc, q, or Left goes back, and quits at the root. A number, then Enter, still picks that row. Ctrl-C restores the terminal and exits 130. `NO_COLOR` keeps the `>` marker and skips reverse video. Text prompts stay line input. A non-terminal, `--yes`, `NVM_NONINTERACTIVE`, and `CI` still skip the menu.

## [v2.8.0] - 2026-10-23

### Added

- `nvm mirror ls` prints every supported download host. `china` also writes sqlite3, canvas, grpc, grpc-tools, nodejieba, xprofiler, gdal-async, ali-zeromq, and ali-usb_ctl. Each key is the env or npmrc name that package's installer reads, and the URL is the npmmirror path that installer requests.
- The README, the site docs, and `skills/znvm/SKILL.md` list every host with its env and npmrc key. Packages that cnpm switches by rewriting files, and packages with no verified host env or a mismatched path, stay unset.

## [v2.7.0] - 2026-10-23

### Added

- `--json` writes one JSON object to stdout for `nvm ls`, `nvm ls-remote` (including `--lts`), `nvm current`, `nvm which`, `nvm version`, `nvm --version`, `nrm ls`, `nrm current`, `nrm test`, `nrm scope ls`, `nvm mirror ls`, and `nvm mirror test`. A `--json` error is `{"error":"...","exit":N}` on stderr, stdout is empty, and the exit code is unchanged.
- `nvm --llm` and `nrm --llm` print `skills/znvm/SKILL.md` on stdout and exit. The file is embedded in the binary, so the command and the file match. That is the zero-install way for an agent to learn the tool.
- Menus open only when stdin and the menu stream are terminals. `--yes`, `NVM_NONINTERACTIVE=1`, and a non-empty `CI` skip them. `NO_COLOR` stays plain ASCII. `--guide-step` still draws on stderr.
- `skills/znvm/SKILL.md` is an agent skill for `nvm`, `nrm`, and `nvm mirror`. There is no MCP server.

## [v2.6.0] - 2026-10-23

### Added

- `nvm mirror ls`, `nvm mirror use china|official|auto`, `nvm mirror set <name> <url>`, `nvm mirror reset`, and `nvm mirror test` manage the Node dist mirror and download mirrors for Electron, Playwright, Cypress, puppeteer, sharp, libvips, node-sass, and the other hosts from cnpm's binary-mirror-config. `mirror` is its own `nvm` command. `nrm` does not accept `binary` or `mirror`.
- Those values are written where the tools read them: npm, pnpm, and yarn v1 rc keys, plus `$NVM_DIR/binaries.env`. `nvm.sh` sources that file. `nvm mirror reset` removes only that block.
- `nrm test` measures registries in parallel. `nrm use auto` writes the fastest healthy registry. `nvm mirror test` and `nvm mirror use auto` do the same for download mirrors, one tool at a time. Results stay in `$NVM_DIR/mirror-latency.json` for 6 hours. Nothing measures on install.
- `@scope` routes are left unchanged by auto-selection.
- In a terminal, `nrm` with no arguments opens a menu for registries, scopes, and tests. The `nvm` guide adds a Mirrors entry.

Docker image mirrors are not part of this release. Pointing a Docker daemon at a mirror needs a privileged config and a daemon restart.

## [v2.5.1] - 2026-10-23

### Fixed

- Re-running `install-as-nvm.sh` or `install.sh` replaces an existing binary when its `--version` differs from the release being installed. The previous file is kept as `nvm.bak` or `znvm.bak`. A failed download leaves the current binary in place.
- `install-as-nvm.sh` prints `ok Upgraded nvm vX -> vY` after that replacement, then links `nrm` to the new binary.

## [v2.5.0] - 2026-10-22

### Added

- One install provides `nvm` and `nrm`. `nrm` is the same binary, installed as a relative symlink beside `nvm` (or `znvm`).
- `nrm ls`, `nrm use <name>`, `nrm current`, `nrm add <name> <url>`, `nrm del <name>`, `nrm test [name]`, and `nrm help`.
- `nrm scope add`, `nrm scope ls`, and `nrm scope del` edit `@scope` routes on the same map as `nvm registry`.
- In a terminal, `nrm` with no arguments opens the registry menu. Without a terminal it prints help.
- Installers do not replace an existing `nrm`. They print the other path and leave that file in place. `install-as-nvm.sh` moves its directory to the front of `PATH` so the linked `nrm` runs first.
- `--uninstall` removes this install's binary and its `nrm` link, restores or removes the shell block, and does not delete Node versions or a foreign `nrm`.

### Changed

- CLI text is plain ASCII. Install scripts say `ok` or `error:` instead of check marks, crosses, arrows, or emoji. The help title uses a hyphen.
- Registry failures start with `error:`.
- Chinese guide prompts keep the words and use ASCII punctuation.

## [v2.4.0] - 2026-10-22

### Added

- `nvm` with no arguments opens an interactive guide in a terminal. `nvm guide` and `nvm interactive` open the same menu.
- The menu installs, switches, lists, and uninstalls Node by calling the existing commands. Number then Enter selects an item.
- Prompts follow `LC_ALL` / `LC_MESSAGES` / `LANG` when the locale starts with `zh`. Otherwise they are English.
- Without a terminal, `nvm` prints a short notice and exits.
- `nvm registry` stores a default registry and any number of `@scope` routes, then writes `~/.npmrc`, `~/.yarnrc`, `~/.yarnrc.yml`, the pnpm rc, and `~/.bunfig.toml`.
- `nvm registry china` sets the default to `https://registry.npmmirror.com` and keeps scopes. `nvm registry official` sets `https://registry.npmjs.org` and keeps scopes.
- The interactive guide can view, add, edit, and delete those routes, set the default, sync every package manager, or restore the official registry.

### Fixed

- Recognize the active Node version when `NVM_DIR` is a symlink. On macOS, `/var` and `/tmp` are links to `/private/var` and `/private/tmp`.

## [v2.2.2] - 2026-07-15

### Fixed

- Fall back to macOS x64 Node.js archives on Apple Silicon when old releases have no arm64 build.

## [v2.2.1] - 2026-07-15

### Fixed

- Validate custom npm prefixes and keep shared command paths idempotent.
- Keep shared global commands ahead of legacy version-local shims.
- Make the release workflow succeed when install scripts already match the tag.

## [v2.2.0] - 2026-07-15

### Added

- `znvm install <major>` selects the newest release on that Node.js version line.
- Global npm packages are shared across Node.js versions through `ZNVM_NPM_PREFIX`.

### Fixed

- Version prefix matching now respects semantic-version segment boundaries.
- Shell environment output safely quotes paths and handles output larger than 8 KiB.

## [v2.1.2] - 2026-03-16

### Fixed

- **修复 shell 启动时未使用 default 版本的问题**
  - `znvm env` 生成的脚本现在会在新终端启动时检查 `.nvmrc` 或 `default` 版本
  - 优先级：`.nvmrc` > `default`
  - 确保在非 git 项目目录下也能自动启用 Node.js

## [v2.1.1] - 2026-03-16

### Added

- **性能基准测试** (`benchmarks/benchmark_key_operations.sh`)
  - 当时加入了一个对比脚本
  - 该脚本的方法和随它发布的数字已撤回，见下方说明

### Changed

- **文档站点更新**
  - 更新主页 (`docs/pages/index.mdx`, `docs/pages/zh/index.mdx`) 添加性能对比表格
  - 新增博客文章 "Why Zig?" (`docs/pages/blog/why-zig.mdx`, `docs/pages/zh/blog/why-zig.mdx`)
  - 本条目原先写过一组 Apple M4 性能数字（list/use/.nvmrc 为 708/192/189 ms、6/4/10 ms、4/3/2 ms，以及 “95–177 倍”）。那些数字不是可复现测量，已撤回，不要把它们当作 v2.1.1 的结果。
  - 当前测量在 2026-10-22，方法是 `benchmarks/measure.py`，结果见 README 的 Benchmarks 和 `benchmarks/results/2026-10-22.json`。那次测量不是本版本发布时做的，不要把新数字回写成 2026-03-16 的发布数据。

### Breaking Changes

**架构重构**: 从纯 Shell 脚本迁移到 Zig + Shell 混合架构

```
v1.x: znvm.sh (纯 Shell)
v2.0.0: znvm-core (Zig 二进制) + znvm.sh (Shell 包装器)
```

**项目结构**:
```
src/
├── main.zig      # 入口点
├── commands.zig  # 命令实现 (install, use, ls, uninstall, default)
├── config.zig    # 配置管理
├── util.zig      # 工具函数
└── version.zig   # 版本解析
```

**命令变更**:
| 命令 | v1.x | v2.0.0 |
|------|------|--------|
| `znvm ls` | 纯文本列表 | 带标记 `[*]` 当前, `[->]` 默认 |
| `znvm default` | ✓ | ✓ (恢复) |

**兼容性**: ✅ 所有 v1.x 命令继续支持，`.nvmrc` 格式不变，已安装版本无需重新安装

### Changed

- **代码模块化**: 核心逻辑拆分为多个 Zig 模块
- **ls 命令改进**: 显示 `[*]` 标记当前版本，`[->]` 标记默认版本
- **文档整合**: 移除独立 docs 目录，迁移到 website 统一管理
- **清理冗余**: 删除 QUICK_START.md 和旧版 docs 目录

### Added

- **Zig 核心**: 全新的 Zig 实现。本条目原先写的 “启动速度 < 5ms” 已撤回；启动时间以 2026-10-22 的测量为准（README Benchmarks）
- **default 命令**: 恢复设置/查看默认版本功能
- **文档站点**: 新增 website 配置和完整文档 (znvm.dev)

### Fixed

- 修复 release workflow 配置
- 优化 install.sh 安装脚本
- 修复版本解析和 SemVer 匹配

## [v1.1.2] - 2026-03-12

### Fixed

- 修复 zsh 中 `for` 循环的 `2>/dev/null` 重定向语法错误（移到 `done` 后）

## [v1.1.1] - 2026-03-12

### Fixed

- 修复 zsh 兼容性问题：`_znvm_get_installed_versions` 函数中的重定向语法

## [v1.1.0] - 2026-03-11

### Fixed

- 修复 Bash 兼容性问题：将 shebang 从 `#!/bin/zsh` 改为 `#!/bin/bash`
- 修复 `uninstall` 命令的 default 版本清理逻辑错误
- 修复 release workflow 的 checkout ref 问题，确保构建正确 tag

### Changed

- 简化 Linux 架构检测逻辑，使用前缀匹配替代复杂字符串处理
- 优化 cd 自动切换性能：只在当前目录查找 `.nvmrc`，不再递归向上
- 改进版本号管理：统一使用 `ZNVM_VERSION` 变量，CI 自动同步更新

### Added

- 添加下载进度显示（移除 `--progress-bar` 重定向到 `/dev/null`）
- 添加 curl 重试延迟参数 `--retry-delay 3`
- 扩展 CI 测试覆盖：添加 `semver compare`、`semver match`、`latest`、`lts` 测试用例

## [v1.0.8] - 2026-03-11 [`4e148d2`](https://github.com/charlzyx/znvm/commit/4e148d2)

### Added

- 添加 cd 自动切换版本功能（通过 `ZNVM_AUTO_SWITCH` 环境变量控制，默认开启）
- 支持 Zsh 和 Bash 的目录切换 hook
- 只在当前目录查找 `.nvmrc` 文件（不进行递归）
- 缓存机制避免重复检测

## [v1.0.7] - 2026-02-09 [`2b1aad0`](https://github.com/charlzyx/znvm/commit/2b1aad0)

### Fixed

- CI 流程优化

## [v1.0.6] - 2026-02-09 [`047b907`](https://github.com/charlzyx/znvm/commit/047b907)

### Changed

- 重构核心功能并增强版本管理逻辑
- 优化版本匹配算法
- 改进错误处理

## [v1.0.5] - 2026-02-05 [`8dd13e3`](https://github.com/charlzyx/znvm/commit/8dd13e3)

### Changed

- 优先使用 `.nvmrc` 文件自动加载版本（use 命令无参数时）
- 回退到 default 版本当 `.nvmrc` 不存在时

### Added

- 添加全局包隔离功能
- 新增 `list-global` / `lg` 命令查看当前版本全局包
- 每个 Node 版本独立的全局包环境

## [v1.0.4] - 2026-02-04 [`7f05112`](https://github.com/charlzyx/znvm/commit/7f05112)

### Added

- 添加版本卸载功能（`uninstall` / `rm` 命令）
- 卸载前检查全局包并提示
- 卸载时自动清理 default 设置

### Changed

- 优化文档和 help 输出
- 改进 CI 流程

## [v1.0.3] - 2026-02-04 [`64669dc`](https://github.com/charlzyx/znvm/commit/64669dc)

### Changed

- 重构版本获取逻辑：使用 `node -v` 替代解析 PATH
- 优化版本列表显示（当前版本 `->`，default 版本标记）

### Fixed

- 修复 `znvm.sh` 中的若干问题
- 清理 `install.sh` 的版本逻辑

## [v1.0.2] - 2026-02-04 [`dcd7d1d`](https://github.com/charlzyx/znvm/commit/dcd7d1d)

### Fixed

- 修复 release workflow
- 修复 build job 的 checkout 引用问题
- 修复并发冲突

## [v1.0.1] - 2026-02-04 [`74d7e80`](https://github.com/charlzyx/znvm/commit/74d7e80)

### Added

- 支持通过 URL 指定版本号安装
- 添加 uninstall 功能

### Changed

- 增强版本管理功能
- 优化用户体验

## [v1.0.0] - 2026-02-04 [`d17dbb5`](https://github.com/charlzyx/znvm/commit/d17dbb5)

### Added

- 初始版本发布
- Zig 核心：SemVer 解析、版本匹配、架构检测
- Shell 包装器：环境管理、下载安装
- 支持 macOS (Apple Silicon/Intel) 和 Linux
- 支持 LTS 版本别名（lts, lts/argon 等）
- Apple Silicon 自动回退到 Rosetta (x64) 模式
- 镜像源加速支持（`NVM_NODEJS_ORG_MIRROR`）
- 双语支持（中文/英文）

## 版本命名规则

- 主版本号：重大架构变更或不兼容改动
- 次版本号：新功能添加（向后兼容）
- 修订号：bug 修复或文档更新

<!-- 版本对比链接 -->
[v2.8.3]: https://github.com/charlzyx/znvm/compare/v2.8.2...v2.8.3
[v2.8.2]: https://github.com/charlzyx/znvm/compare/v2.8.1...v2.8.2
[v2.8.1]: https://github.com/charlzyx/znvm/compare/v2.8.0...v2.8.1
[v2.8.0]: https://github.com/charlzyx/znvm/compare/v2.7.0...v2.8.0
[v2.7.0]: https://github.com/charlzyx/znvm/compare/v2.6.0...v2.7.0
[v2.6.0]: https://github.com/charlzyx/znvm/compare/v2.5.1...v2.6.0
[v2.5.1]: https://github.com/charlzyx/znvm/compare/v2.5.0...v2.5.1
[v2.5.0]: https://github.com/charlzyx/znvm/compare/v2.4.0...v2.5.0
[v2.4.0]: https://github.com/charlzyx/znvm/compare/v2.3.0...v2.4.0
[v2.2.2]: https://github.com/charlzyx/znvm/compare/v2.2.1...v2.2.2
[v2.2.1]: https://github.com/charlzyx/znvm/compare/v2.2.0...v2.2.1
[v2.2.0]: https://github.com/charlzyx/znvm/compare/v2.1.2...v2.2.0
[v2.1.2]: https://github.com/charlzyx/znvm/compare/v2.1.1...v2.1.2
[v2.1.1]: https://github.com/charlzyx/znvm/compare/v2.0.0-rc.1...v2.1.1
[v2.0.0-rc.1]: https://github.com/charlzyx/znvm/compare/v1.1.2...v2.0.0-rc.1
[v1.0.8]: https://github.com/charlzyx/znvm/compare/v1.0.7...v1.0.8
[v1.0.7]: https://github.com/charlzyx/znvm/compare/v1.0.6...v1.0.7
[v1.0.6]: https://github.com/charlzyx/znvm/compare/v1.0.5...v1.0.6
[v1.0.5]: https://github.com/charlzyx/znvm/compare/v1.0.4...v1.0.5
[v1.0.4]: https://github.com/charlzyx/znvm/compare/v1.0.3...v1.0.4
[v1.0.3]: https://github.com/charlzyx/znvm/compare/v1.0.2...v1.0.3
[v1.0.2]: https://github.com/charlzyx/znvm/compare/v1.0.1...v1.0.2
[v1.0.1]: https://github.com/charlzyx/znvm/compare/v1.0.0...v1.0.1
[v1.0.0]: https://github.com/charlzyx/znvm/releases/tag/v1.0.0
