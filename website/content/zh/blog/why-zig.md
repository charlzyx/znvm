# 为什么用 Zig

2026-10-22，source nvm 的热启动多 113 ms，冷启动多 121 ms。ZNVM 是一个 Zig 二进制：没有垃圾回收，也没有异步运行时。`nvm use` 解析版本，并打印给 shell `eval` 的导出。

在这台 Linux 虚拟机上，shell 里的命令比 NVM 和 fnm 快。shell 启动比 NVM 快，比 fnm 慢。

## 测量

配对中位数，2026-10-22 15:38-15:40 UTC。4 核 KVM（Intel Xeon），Ubuntu 24.04。ZNVM ReleaseSafe，3.73 MiB，未 strip。方法：`benchmarks/measure.py`。样本：`benchmarks/results/2026-10-22-cold-warm.json`。冷启动每次丢掉页缓存，共 20 次。冷命令在已打开的 shell 里丢掉文件缓存。

| 管理器 | 热启动 | 冷启动 | list 热 | list 冷 | use 热 | use 冷 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 121 ms | 559 ms | 557 ms | 158 ms | 221 ms |
| `fnm` | 1.58 ms | 4.70 ms | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms |
| **`znvm`** | **3.31 ms** | **5.01 ms** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** |

`.nvmrc` 中位数，热 / 冷：NVM 166 / 222 ms，fnm 1.41 / 5.20 ms，ZNVM 0.86 / 3.06 ms。shell 启动 p95，热 / 冷：NVM 115 / 128 ms，fnm 1.76 / 6.67 ms，ZNVM 3.64 / 9.28 ms。fnm 的 init 当时已经激活 Node v22.14.0。更早的 Node 22.13.1 安装（含下载，3 次：ZNVM 1241 ms，fnm 2317 ms，NVM 2327 ms）在 `benchmarks/results/2026-10-22.json`，这次没有重跑。

只支持 macOS 和 Linux。
