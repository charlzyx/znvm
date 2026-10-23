# Why Zig

Sourcing nvm added 113 ms warm and 121 ms cold on 2026-10-22. znvm is a Zig binary: no garbage collector, no async runtime. `nvm use` resolves a version and prints exports for the shell to `eval`.

On this Linux VM, in-shell commands were faster than nvm and fnm. Shell startup was faster than nvm and slower than fnm.

## Measurements

Paired medians, 2026-10-22 15:38-15:40 UTC. 4-vCPU KVM (Intel Xeon), Ubuntu 24.04. znvm ReleaseSafe, 3.73 MiB, not stripped. Method: `benchmarks/measure.py`. Samples: `benchmarks/results/2026-10-22-cold-warm.json`. Cold startup drops the page cache before each of 20 samples. Cold commands drop the file cache inside an already-open shell.

| Manager | Warm startup | Cold startup | list warm | list cold | use warm | use cold |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 121 ms | 559 ms | 557 ms | 158 ms | 221 ms |
| `fnm` | 1.58 ms | 4.70 ms | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms |
| **`znvm`** | **3.31 ms** | **5.01 ms** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** |

`.nvmrc` medians, warm / cold: nvm 166 / 222 ms, fnm 1.41 / 5.20 ms, znvm 0.86 / 3.06 ms. Shell-startup p95, warm / cold: nvm 115 / 128 ms, fnm 1.76 / 6.67 ms, znvm 3.64 / 9.28 ms. fnm's init already had Node v22.14.0. An earlier Node 22.13.1 install (3 samples, download included: znvm 1241 ms, fnm 2317 ms, nvm 2327 ms) is in `benchmarks/results/2026-10-22.json` and was not repeated.

macOS and Linux only.
