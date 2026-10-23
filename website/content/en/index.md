## Install

```bash
curl -fsSL https://znvm.dev/install-as-nvm.sh | bash
```

NVM and NRM, written in Zig. Versions live in `~/.nvm`. Downloads use npmmirror. Run `nvm` to open the guide.

Warm / cold shell startup on 2026-10-22: ZNVM 3.31 / 5.01 ms, fnm 1.58 / 4.70 ms, NVM 113 / 121 ms.

## Speed

One run, 2026-10-22 15:38-15:40 UTC. 4-vCPU KVM (Intel Xeon), Ubuntu 24.04. `benchmarks/measure.py`. ZNVM ReleaseSafe. Samples: `benchmarks/results/2026-10-22-cold-warm.json`.

| Manager | Warm startup | Cold startup | list warm | list cold | use warm | use cold | .nvmrc warm | .nvmrc cold |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 121 ms | 559 ms | 557 ms | 158 ms | 221 ms | 166 ms | 222 ms |
| `fnm` | 1.58 ms | 4.70 ms | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms | 1.41 ms | 5.20 ms |
| **`znvm`** | **3.31 ms** | **5.01 ms** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** | **0.86 ms** | **3.06 ms** |

Shell-startup p95, warm / cold: nvm 115 / 128 ms, fnm 1.76 / 6.67 ms, znvm 3.64 / 9.28 ms. On this run fnm started the shell faster. znvm was faster in the shell. An earlier install (download included, 3 samples: znvm 1241 ms, fnm 2317 ms, nvm 2327 ms) is in `benchmarks/results/2026-10-22.json`.

macOS and Linux. One static binary.
