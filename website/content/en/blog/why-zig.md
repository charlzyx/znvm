# Why Zig? The Quest for the Zero-Overhead Workflow

In the modern dev ecosystem, we've grown accustomed to "fast enough." But as developers who live in the terminal, "fast enough" is a lie.

Every time you open a new shell tab, a heavy version manager adds time before the prompt is usable. On the 2026-10-22 measurement below, sourcing nvm added 118 ms. That is the cost this project is aimed at.

I built **znvm** because I wanted to reclaim those milliseconds, and **Zig** was the only language that made sense for this mission.

## 1. Performance is a Feature, Not an Afterthought

Rust is great, but Zig offers a level of raw, predictable control that is unparalleled.

In znvm, we don't have a garbage collector waking up at the wrong time. We don't have complex async runtimes bloating our binary.

Zig has no garbage collector and no async runtime in znvm. `znvm use` is still a process: it resolves a version and prints the exports that the shell `eval`s. The table below is one Linux VM, measured with `benchmarks/measure.py`. It does not say every operation is faster than every other manager. On this run, in-shell commands were quicker than nvm and fnm, and shell startup was quicker than nvm and slower than fnm.

## 2. The "No Hidden Control Flow" Philosophy

Zig's mantra—**no hidden control flow, no hidden memory allocations**—perfectly aligns with what a version manager should be.

A tool that manages your PATH and environment should be **invisible and transparent**. Zig allows znvm to be a surgical tool: it does exactly what it needs to do with the environment variables and filesystem, then disappears.

No background daemons, no heavy metadata syncing.

## 3. Performance & Binary Size

Warm medians, 2026-10-22, 4-vCPU KVM guest (Intel Xeon, Ubuntu 24.04), znvm ReleaseSafe (3.73 MiB, not stripped). Method: `benchmarks/measure.py`. Raw samples: `benchmarks/results/2026-10-22.json`.

| Manager | Shell startup | `list` | `use` | `.nvmrc` | Size |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `nvm` | 118 ms | 527 ms | 153 ms | 166 ms | 146.7 KiB script |
| `fnm` | 1.58 ms | 1.31 ms | 1.46 ms | 1.43 ms | 7.03 MiB |
| **`znvm`** | **3.55 ms** | **0.62 ms** | **0.89 ms** | **0.97 ms** | **3.73 MiB** |

Shell startup is a fresh bash minus `bash -c true`. fnm's documented init already had Node v22.14.0 active, so 1.58 ms is the startup in the table. Installing Node 22.13.1 from nodejs.org (3 samples, download included) was 1241 ms for znvm, 2317 ms for fnm, and 2327 ms for nvm. That install gap is mostly network.

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
