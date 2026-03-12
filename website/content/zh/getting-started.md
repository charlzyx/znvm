# 快速开始

**znvm** — **零负担 Node 版本管理器**

基于 Zig 构建的极速、零配置 **Node.js 版本管理器**。以 **< 5ms** 的启动时间解决 **nvm 卡顿** 问题。

## 安装

### 快速安装（推荐）

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

然后重启终端或运行：

```bash
source ~/.zshrc  # 或 ~/.bashrc
```

### 安装器做了什么

1. 检测您的平台（macOS/Linux）和架构（x64/arm64）
2. 下载最新的 `znvm` 二进制文件到 `~/.znvm/bin/`
3. 在 shell 配置中将 `znvm` 添加到 `PATH`
4. 设置 shell 包装器以支持 `use` 命令和自动切换

### Shell 配置

如果自动设置未生效，请添加以下内容到您的 shell 配置文件（`~/.zshrc`、`~/.bashrc` 等）：

```bash
eval "$(znvm env)"
```

此命令会：
- 将 `znvm` 添加到您的 PATH
- 设置 `use` 命令的 shell 包装器
- 启用 `cd` 到带有 `.nvmrc` 目录时的自动切换

## 使用

### 安装 Node.js

znvm 支持 SemVer 模式。使用 `22` 即可获取最新的 v22.x.x：

```bash
znvm install 22           # 最新的 v22.x.x
znvm install 20.11.0      # 特定版本
znvm install v18.20.0     # 带 v 前缀
```

### 切换版本

```bash
znvm use 20               # 切换到 Node 20
znvm use                  # 从 .nvmrc 自动检测
```

### 列出已安装版本

```bash
znvm ls
# 或
znvm list
```

输出显示：
- `[*]` - 当前激活版本
- `[->]` - 默认版本

### 设置默认版本

```bash
znvm default 20           # 设置 v20 为默认
znvm default              # 显示当前默认版本
```

默认版本在以下情况使用：
- 当前目录不存在 `.nvmrc` 文件
- `.nvmrc` 中的版本未安装

### 卸载版本

```bash
znvm uninstall 20
# 或
znvm rm 20
```

## 使用 .nvmrc 自动切换

当您 `cd` 到带有 `.nvmrc` 的目录时，znvm 会自动切换 Node 版本：

```bash
echo "20" > .nvmrc        # 创建 .nvmrc
cd /my-project            # 自动切换到 Node 20
```

> **注意：** 当您在 shell 配置中使用 `eval "$(znvm env)"` 时，自动切换默认启用。

## 环境变量

| 变量 | 描述 | 默认值 |
|------|------|--------|
| `ZNVM_DIR` | znvm 安装目录 | `~/.znvm` |
| `NVM_NODEJS_ORG_MIRROR` | Node.js 下载镜像 | - |

## 镜像配置

中国用户可使用镜像加速下载：

```bash
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
```

## 全局包隔离

每个 Node.js 版本都有独立的：
- 全局 npm 包（`npm install -g`）
- npm 缓存
- Corepack（pnpm/yarn）

这可以防止不同 Node 版本之间的冲突。

## 命令参考

| 命令 | 描述 |
|------|------|
| `znvm install <ver>` | 安装 Node.js 版本 |
| `znvm use [ver]` | 切换到版本（或使用 .nvmrc） |
| `znvm ls` | 列出已安装版本 |
| `znvm default [ver]` | 设置/显示默认版本 |
| `znvm uninstall <ver>` | 移除版本 |
| `znvm version` | 显示 znvm 版本 |
| `znvm env` | 输出 shell 配置 |

## 故障排除

### 命令未找到

确保 `~/.znvm/bin` 在您的 PATH 中：

```bash
export PATH="$HOME/.znvm/bin:$PATH"
```

### 安装后版本未找到

运行 `znvm use <version>` 或重启终端。

### 自动切换不工作

确保 shell 包装器已在您的配置中加载：

```bash
eval "$(znvm env)"
```

如需禁用自动切换，从 shell 配置中移除或注释掉 `eval "$(znvm env)"` 这一行。

---

**相关：** [为什么构建 znvm](/zh/blog/why-zig) | [GitHub](https://github.com/charlzyx/znvm)
