# Changelog

所有显著变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [v2.1.2] - 2026-03-16

### Fixed

- **修复 shell 启动时未使用 default 版本的问题**
  - `znvm env` 生成的脚本现在会在新终端启动时检查 `.nvmrc` 或 `default` 版本
  - 优先级：`.nvmrc` > `default`
  - 确保在非 git 项目目录下也能自动启用 Node.js

## [v2.1.1] - 2026-03-16

### Added

- **性能基准测试** (`benchmarks/benchmark_key_operations.sh`)
  - 完整的性能对比测试脚本
  - 测试关键操作：`list`, `use`, `.nvmrc` 解析
  - 对标 nvm 和 fnm 的真实性能数据

### Changed

- **文档站点更新**
  - 更新主页 (`docs/pages/index.mdx`, `docs/pages/zh/index.mdx`) 添加性能对比表格
  - 新增博客文章 "Why Zig?" (`docs/pages/blog/why-zig.mdx`, `docs/pages/zh/blog/why-zig.mdx`)
  - 完整的真实基准测试数据 (Apple M4, 16GB RAM, macOS 25.3)

**性能数据对比**:

| 管理器 | list | use | .nvmrc |
|--------|------|-----|--------|
| nvm | 708ms | 192ms | 189ms |
| fnm | 6ms | 4ms | 10ms |
| **znvm** | **4ms** | **3ms** | **2ms** |

**性能优势**: znvm 快 **95-177 倍** (相比 nvm)

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

- **Zig 核心**: 全新的 Zig 实现，启动速度 < 5ms
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
