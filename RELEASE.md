# 发布指南 / Release Guide

## 发布前的共同要求

- Windows x64 + ARM64 支持属于向后兼容的平台功能，当前候选版本为 **v2.10.0**。
- 在 PR 中同步源码 `--version`、debug 版本、测试预期、两个根安装脚本、网站版本、skill 示例和 CHANGELOG；运行 `scripts/sync-install-sh.sh` 同步网站安装脚本。发布流水线不替你改源码版本。
- 同一最终 SHA 必须通过 macOS/Linux 回归和 Windows x64/ARM64 原生 CI。交叉编译不能代替原生测试。
- 先审核完整 workflow/script diff 与版本资产清单，再授权合并/发布。**合并候选 PR 后到发布终态之间冻结 main**；流水线多次检查 main 是否仍为触发 SHA，变化即停止。
- 两条流水线都固定 Zig `0.17.0`、`ReleaseSafe`，不自动提交到 main、不移动/重打 tag、不覆盖同名资产。

## 一次性 v2.10.0 发布入口（首选）

`.github/workflows/release-request.yml` 仅由 **push main 且根 `release-request.json` 发生变化**触发。marker 必须严格为：

```json
{"enabled": true, "version": "2.10.0"}
```

这个 PR 合并会触发发布，**因此 merge 是发布授权边界，不是单纯代码整理**。PR、feature branch、手动任意输入都不能触发；固定 concurrency `release-v2.10.0` 串行运行，`cancel-in-progress: false`。

流程如下：

1. 只读 guard 检查 push/main、完整 commit SHA、固定 marker、源码/安装器/网站版本、网站安装器 byte 一致、Zig pin、当前远端 main 与该 SHA 一致。查询 GitHub tag/release，release 发现使用分页列表以覆盖可见 draft（不依赖仅保证 published 的按 tag 查询）；重复同 tag 对象即停止，403/网络错误不能被当作“不存在”。初始只读 token 可能不可见 draft，因此其通过只是预检；最终发布 job 使用 write token 重复全部状态检查，不把只读不可见当作发布依据。
2. 构建四个 Unix 二进制及两个 Windows ZIP，并保存独立的 build-time SHA-256 manifest 到 Actions artifact。Unix 沿用 Ubuntu 交叉编译，Windows 在对应 `windows-latest` / `windows-11-arm` 原生 runner 构建。Windows ZIP 固定 entry 顺序与时间戳，包含 `bin/nvm.exe`、同字节的 `bin/nrm.exe`、`cmd/nvm.cmd`、`cmd/init.cmd`、`cmd/finish.cmd` 和根 `WINDOWS.md`。
3. 下载构建 artifacts，与构建时 hash 比对，汇总成六行 `SHA256SUMS`，形成七文件 release candidate artifact。
4. Windows x64、ARM64 原生 runner 下载该 candidate，检查 hash、`--version` 与版本一致，解压 ZIP 后执行 `windows-smoke.ps1`、`windows-cmd-smoke.ps1`、`windows-bash-smoke.ps1`，都传入真实解压的 `bin/nvm.exe` 和 `-ExpectedArch x64/arm64`；cmd smoke 另传 `-PackageRoot` 使用 ZIP 内真实 shim。还执行打包的 `nrm.exe --version` / `nrm.exe ls`。测试检查 OS/PowerShell/PE 架构，在临时 HOME/PATH 中安装并运行对应架构真实 Node，验证 npm/npx、切换和失败隔离。
5. **只有以上全部成功**，publish job 才取得 `contents: write`。重新检查 main、tag、release，创建指向精确 SHA 的 draft release，严格验证返回的正整数 ID、draft/tag/source SHA 与空资产集合，立即 flush ownership receipt。后续上传仅使用此数字 release ID；逐个记录返回的 asset ID/name/size/hash，不按可变 tag 名解析写入目标、不使用 `--clobber`。
6. 认证下载已记录的每个 asset ID，与刚刚原生测试过的 candidate hashes/size 比对。发布前再次读取同一 release ID、核验完整 asset ID 集合、main 和 tag 所有权；最后 PATCH 同一 release ID 发布。tag 被替换或同名资产换 ID 一律停止。此模式支持先上传再发布的 immutable-release 流程。
7. 发布后仍读取同一 release ID，核对 tag commit、完整七资产 ID 集合，认证及匿名下载校验全部七文件，确认 main 没有改变。全绿才宣布发布完成。 匿名下载对 CDN 404/5xx 或连接中断仅重试同一 URL，最多 5 次（退避共 33 秒）；权限错误和 hash 不同立即停止，不触发重新发布。

`GITHUB_TOKEN` 发布 release 不会递归触发下述 `release.published` workflow；不要替换为 PAT/App token 而不重新审核重复发布风险。

### 幂等与失败：不自动修复远端状态

- tag/release 均不存在：允许首次发布。
- 已有完整 published release：只有 tag 指向同一 SHA、恰好七个预期名字、重建候选的全部 hash 与远端匹配、匿名下载也通过，才作为无写入幂等成功。
- 只有 tag、只有 release、draft、错误 SHA、缺失/额外/重复资产、hash 不同：**fail closed**，需要操作者先读取实际状态并明确授权恢复。绝不将“存在”直接当成功。
- draft 创建后的任何失败都保留 draft/资产，供调查；不会自动删除、覆盖、重建或移动 tag。不要盲目 rerun 试图修复部分发布。发布成功但后置下载失败也必须检查实际状态，不能重发同版本。
- marker 保留不会让普通 main 变更触发发布。未来版本需要单独审核新版本流程；不能只改这个受限 marker 的版本字符串复用。

## 手动发布兼容入口

`.github/workflows/release.yml` 监听 **`release.published`**（包括 draft → publish），**不是 tag push**。这是保留的手动兼容路径，不用于上面的一次性自动入口。

只有得到明确授权并有可用 GitHub 写入入口后，才在已审核/测试的精确 main commit 创建 tag，再在 GitHub Release UI 选择该 tag 发布。未登录的 `gh` 或只读 connector 不是成功发布的证据。不要 force-move tag。

兼容路径沿用“先发布页面，再构建/上传资产”，因此要求 mutable、非 draft、非 prerelease 的 `vX.Y.Z` release。preflight 拒绝 immutable releases；旧 release 的 `immutable=false` 不能证明当前仓库设置。immutable 仓库应使用前述 draft 预上传流程。

兼容流水线构建六目标、保存 build manifests、上传不覆盖、匿名下载六文件逐一核验、上传并回读 `SHA256SUMS`，然后在 Windows 两个原生架构下载已发布 Windows ZIP 校验 hash、解压后核验 nvm/nrm version 并运行 PowerShell/cmd/Git Bash 三 shell smoke。最后只读检查 main 安装器和网站版本，不提交修改。同一 tag 的运行串行，不取消正在发布任务。页面出现不代表发布成功，必须等全部 jobs 通过。

## 资产与校验

```text
znvm-v2.10.0-x86_64-linux-musl
znvm-v2.10.0-aarch64-linux-musl
znvm-v2.10.0-x86_64-macos
znvm-v2.10.0-aarch64-macos
znvm-v2.10.0-x86_64-windows.zip
znvm-v2.10.0-aarch64-windows.zip
SHA256SUMS
```

Actions candidate/manifests 保留 30 天，release 的公开 `SHA256SUMS` 持续用于完整性校验；它不是代码签名。Unix 下载目标二进制及同一 release 的 manifest 后使用 `sha256sum --check --ignore-missing SHA256SUMS`；Windows 使用 `Get-FileHash -Algorithm SHA256 <zip>` 与对应行比较。`--version` 应输出 `v2.10.0`。

Unix 安装示例（Windows 见 README / WINDOWS.md 的三 shell 步骤）：

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/v2.10.0/install.sh | bash
```

## 本地 guard 测试

```bash
python3 scripts/test-release-request.py
```

这些纯 fixture/mock 测试涵盖 main 移动、错误事件/marker、部分 draft/tag、错误 SHA、缺失/重复资产、API 拒绝、hash 篡改与路径穿越，不访问 GitHub、不创建发布对象。真正 release 流水线只在获授权的 main marker merge 后验证，不能把这组单测或普通 PR CI 说成已发版。
