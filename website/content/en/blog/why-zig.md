# Why Zig? The Quest for the Zero-Overhead Workflow

In the modern dev ecosystem, we've grown accustomed to "fast enough." But as developers who live in the terminal, "fast enough" is a lie.

Every time you open a new shell tab, a heavy version manager adds time before the prompt is usable. On the 2026-10-22 measurement below, sourcing nvm added 113 ms with a warm page cache and 121 ms when the cache was dropped before each run. That is the cost this project is aimed at.

I built **znvm** because I wanted to reclaim those milliseconds, and **Zig** was the only language that made sense for this mission.

## 1. Performance is a Feature, Not an Afterthought

Rust is great, but Zig offers a level of raw, predictable control that is unparalleled.

In znvm, we don't have a garbage collector waking up at the wrong time. We don't have complex async runtimes bloating our binary.

Zig has no garbage collector and no async runtime in znvm. `nvm use` is still a process: it resolves a version and prints the exports that the shell `eval`s. The tables below are one Linux VM, measured with `benchmarks/measure.py`, with warm and cold samples. They do not say every operation is faster than every other manager. On this run, in-shell commands were quicker than nvm and fnm both warm and cold, and shell startup was quicker than nvm and slower than fnm in both cases.

## 2. The "No Hidden Control Flow" Philosophy

Zig's mantra—**no hidden control flow, no hidden memory allocations**—perfectly aligns with what a version manager should be.

A tool that manages your PATH and environment should be **invisible and transparent**. Zig allows znvm to be a surgical tool: it does exactly what it needs to do with the environment variables and filesystem, then disappears.

No background daemons, no heavy metadata syncing.

## 3. Performance & Binary Size

Paired medians, 2026-10-22 15:38–15:40 UTC, 4-vCPU KVM guest (Intel Xeon, Ubuntu 24.04), znvm ReleaseSafe (3.73 MiB, not stripped). Method: `benchmarks/measure.py`. Raw samples: `benchmarks/results/2026-10-22-cold-warm.json`. Cold startup drops the page cache before each of 20 samples. Cold commands drop the file cache inside an already-open shell.

| Manager | Warm startup | Cold startup | list warm | list cold | use warm | use cold |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 113 ms | 121 ms | 559 ms | 557 ms | 158 ms | 221 ms |
| `fnm` | 1.58 ms | 4.70 ms | 1.26 ms | 6.10 ms | 1.35 ms | 6.19 ms |
| **`znvm`** | **3.31 ms** | **5.01 ms** | **0.61 ms** | **3.18 ms** | **0.84 ms** | **3.44 ms** |

`.nvmrc` medians, warm / cold: nvm 166 / 222 ms, fnm 1.41 / 5.20 ms, znvm 0.86 / 3.06 ms. Shell-startup p95, warm / cold: nvm 115 / 128 ms, fnm 1.76 / 6.67 ms, znvm 3.64 / 9.28 ms. fnm's documented init already had Node v22.14.0. The earlier Node 22.13.1 install timing (3 samples, download included: znvm 1241 ms, fnm 2317 ms, nvm 2327 ms) was not repeated; it is in `benchmarks/results/2026-10-22.json`.

## 4. The Unix-First Strategic Choice

Zig thrives when you talk directly to the OS. By focusing exclusively on Unix-like systems (macOS and Linux), we avoided the "abstraction tax" that comes with supporting Windows.

This allowed us to use Zig to write highly optimized, platform-specific code that respects the Unix philosophy:

> **Do one thing, and measure it.**

## The Bottom Line

znvm isn't just a tool—it's a statement about how developer tools should be built:

- **Fast** shouldn't mean "fast enough"
- **Simple** shouldn't mean "lacking features"
- **Small** shouldn't mean "incomplete"

Zig gave us the power to prove that you can have all three.

---

**Tags:** znvm, nvm, fnm, nvm-slow, node version manager, zig, performance, zero-overhead, unix-philosophy, minimalism
