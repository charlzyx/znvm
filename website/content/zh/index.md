## 安装

```bash
curl -fsSL https://znvm.dev/install.sh | bash
```

装过原版 NVM？旧的 nvm.sh 和 shell 里的加载行可以清掉，交给 Agent 处理就行。

Zig 写的 NVM 和 NRM。版本在 `~/.nvm`。下载走 npmmirror。直接敲 `nvm` 打开引导。

2026-10-22 热启动 / 冷启动：ZNVM 3.31 / 5.01 ms，fnm 1.58 / 4.70 ms，NVM 113 / 121 ms。

## 速度

同一次运行，2026-10-22 15:38–15:40 UTC。4 核 KVM（Intel Xeon），Ubuntu 24.04。`benchmarks/measure.py`。ZNVM ReleaseSafe。样本：`benchmarks/results/2026-10-22-cold-warm.json`。

| 管理器 | 热启动 | 冷启动 | list 热 | list 冷 | use 热 | use 冷 | .nvmrc 热 | .nvmrc 冷 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 121 ms | 559 ms | 557 ms | 158 ms | 221 ms | 166 ms | 222 ms |
| `fnm` | 1.58 ms | 4.70 ms | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms | 1.41 ms | 5.20 ms |
| **`znvm`** | **3.31 ms** | **5.01 ms** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** | **0.86 ms** | **3.06 ms** |

shell 启动 p95，暖 / 冷：nvm 115 / 128 ms，fnm 1.76 / 6.67 ms，znvm 3.64 / 9.28 ms。这次 shell 启动是 fnm 更快，shell 内命令是 znvm 更快。更早的安装（含下载，3 次：znvm 1241 ms，fnm 2317 ms，nvm 2327 ms）在 `benchmarks/results/2026-10-22.json`。

只支持 macOS 和 Linux。一个静态二进制。
