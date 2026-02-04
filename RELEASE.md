# 发布指南 / Release Guide

## 全自动发布流程 🚀

只需 3 步，CI 自动完成所有工作：

### 1. 创建 Tag

```bash
git tag v0.2.0
git push origin v0.2.0
```

### 2. 创建 Release

在 GitHub 上创建 Release：
- 选择 tag: `v0.2.0`
- 填写 Release Notes
- 点击 **Publish release**

### 3. 等待 CI 完成

CI 会自动完成：
- ✅ 更新 `install.sh` 中的 `ZNVM_VERSION`
- ✅ 提交并推送到 main 分支
- ✅ 更新 tag 指向新的 commit
- ✅ 编译 4 个平台的二进制文件
- ✅ 上传到 Release Assets

## 完整示例

```bash
# 1. 确保 main 分支是最新的
git checkout main
git pull origin main

# 2. 创建 tag
git tag v0.2.0

# 3. 推送 tag（会触发 CI）
git push origin v0.2.0

# 4. 在 GitHub 创建 Release
# 访问：https://github.com/charlzyx/znvm/releases/new
# 选择 tag v0.2.0，填写 Release Notes，点击 Publish

# 5. 等待 CI 完成后，二进制文件自动上传到 Release Assets
```

## 用户安装

发布完成后，用户可以这样安装：

```bash
# 安装指定版本
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/v0.2.0/install.sh | bash
```

## 工作原理

```
你创建 tag v0.2.0 并发布 Release
         ↓
    CI 自动触发
         ↓
    1. 修改 install.sh: ZNVM_VERSION="v0.2.0"
    2. 提交并 push 到 main
    3. 更新 tag 指向新的 commit
         ↓
    4. 编译 4 个平台的二进制文件
    5. 上传到 Release Assets
         ↓
    ✅ 发布完成！
```

### 4. 上传预编译二进制文件

```bash
# 编译所有平台的二进制文件
zig build -Doptimize=ReleaseSafe

# 重命名并上传到 Release
# macOS arm64
cp zig-out/bin/znvm-core znvm-core-v0.2.0-aarch64-macos

# macOS x64
# (需要先构建 x64 版本)
cp zig-out/bin/znvm-core znvm-core-v0.2.0-x86_64-macos

# Linux aarch64
# (需要先构建 Linux aarch64 版本)
cp zig-out/bin/znvm-core znvm-core-v0.2.0-aarch64-linux-musl

# Linux x64
# (需要先构建 Linux x64 版本)
cp zig-out/bin/znvm-core znvm-core-v0.2.0-x86_64-linux-musl
```

## 用户如何安装

发布后，用户可以这样安装指定版本：

```bash
# 安装 v0.2.0 版本
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/v0.2.0/install.sh | bash
```

## 注意事项

⚠️ **重要**: 每次发布新版本时，必须更新 `install.sh` 中的 `ZNVM_VERSION`，否则该版本的安装脚本无法识别自己的版本号。
