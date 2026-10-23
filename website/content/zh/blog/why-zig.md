# 为什么用 Zig

2026-10-22，source nvm 暖启动增加 113 ms，冷启动增加 121 ms。znvm 是 Zig 二进制：没有垃圾回收，没有异步运行时。`nvm use` 解析版本，并打印给 shell `eval` 的导出。

在这台 Linux 虚拟机上，shell 内命令比 nvm 和 fnm 快。shell 启动比 nvm 快，比 fnm 慢。

## 测量

配对中位数，2026-10-22 15:38–15:40 UTC。4 核 KVM（Intel Xeon），Ubuntu 24.04。znvm ReleaseSafe，3.73 MiB，未 strip。方法：`benchmarks/measure.py`。样本：`benchmarks/results/2026-10-22-cold-warm.json`。冷启动每次丢掉页缓存，共 20 次。冷命令在已打开的 shell 里丢掉文件缓存。

| 管理器 | 暖启动 | 冷启动 | list 暖 | list 冷 | use 暖 | use 冷 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 121 ms | 559 ms | 557 ms | 158 ms | 221 ms |
| `fnm` | 1.58 ms | 4.70 ms | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms |
| **`znvm`** | **3.31 ms** | **5.01 ms** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** |

`.nvmrc` 中位数，暖 / 冷：nvm 166 / 222 ms，fnm 1.41 / 5.20 ms，znvm 0.86 / 3.06 ms。shell 启动 p95，暖 / 冷：nvm 115 / 128 ms，fnm 1.76 / 6.67 ms，znvm 3.64 / 9.28 ms。fnm 的 init 当时已经激活 Node v22.14.0。更早的 Node 22.13.1 安装（含下载，3 次：znvm 1241 ms，fnm 2317 ms，nvm 2327 ms）在 `benchmarks/results/2026-10-22.json`，这次没有重跑。

只支持 macOS 和 Linux。
