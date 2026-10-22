#!/usr/bin/env python3
"""Measure znvm, nvm, and fnm the way a shell actually runs them.

The previous benchmarks/benchmark_key_operations.sh script took one `time`
sample, included `source nvm.sh` only in the nvm timings, and called
`znvm resolve` (not a znvm command). This replaces it.

What is timed
  shell startup
    Fresh `bash --noprofile --norc -c` process. Overhead is the median of the
    init command minus the median of `bash -c true` in the same environment.
    "node active" init is the documented shell line, plus an extra `fnm use`
    for the fnm sample that is kept only as a comparison. nvm's `source nvm.sh`
    and znvm's `eval "$(znvm env)"` already put the default Node on PATH.
    With a default alias set, `eval "$(fnm env --use-on-cd)"` does too: the
    2026-10-22 run recorded node v22.14.0 after that init alone. Publish
    fnm's startup_documented overhead for shell startup. The extra `fnm use`
    sample is slower and is not the documented init.
  list / use / .nvmrc
    Inside one already-initialized bash (the init cost is not included).
    Wall time is minus the median of an in-shell `true` measured the same way,
    which removes the printf/pipe harness.
    `use` alternates v20.19.0 and v22.14.0 so each sample changes the active
    version. znvm's shell function evals the exports the binary prints; nvm's
    function edits PATH itself; fnm updates its multishell symlink.
    `.nvmrc` is `use` with no arguments in a directory whose `.nvmrc` contains
    `20.19.0`. The shell is put back on v22.14.0 before each sample (not timed).
    `cd` is the builtin (`\\cd`), not fnm's cd hook.
  install
    Wall time of `install 22.13.1` from https://nodejs.org/dist, including the
    version-index fetch and the tarball download. The tool's download cache and
    installed copies are deleted before every sample. Network time is included.
  cold
    One sample after `sync` and `echo 3 > /proc/sys/vm/drop_caches`, when that
    is permitted. A single sample is not a median and is reported separately.

Each latency data directory has exactly those two Node versions. PATH during
the runs is only the tool binary directory plus /usr/bin:/bin. znvm is the
ReleaseSafe binary passed with --znvm-bin (the shipping optimize mode).

Versions are pinned: nvm v0.40.3, fnm v1.39.0, Node v22.14.0, v20.19.0, and
v22.13.1 for the install timing.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import select
import shutil
import statistics
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

MIRROR = "https://nodejs.org/dist"
NVM_GIT = "v0.40.3"
FNM_VERSION = "v1.39.0"
FNM_URL = f"https://github.com/Schniz/fnm/releases/download/{FNM_VERSION}/fnm-linux.zip"
NODE_A = "22.14.0"
NODE_B = "20.19.0"
NODE_INSTALL = "22.13.1"
TOOLS = ("nvm", "fnm", "znvm")


def log(msg: str) -> None:
    print(msg, flush=True)


def run(cmd: list[str], env: dict[str, str], cwd: Path, timeout: float = 300) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        env=env,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def checked(cmd: list[str], env: dict[str, str], cwd: Path, timeout: float = 300) -> subprocess.CompletedProcess[str]:
    result = run(cmd, env, cwd, timeout)
    if result.returncode != 0:
        raise SystemExit(
            f"command failed ({result.returncode}): {' '.join(cmd)}\n"
            f"stdout:\n{result.stdout[-4000:]}\nstderr:\n{result.stderr[-4000:]}"
        )
    return result


def percentile(values: list[float], p: float) -> float:
    if not values:
        raise ValueError("empty")
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (len(ordered) - 1) * p
    low = int(rank)
    high = min(low + 1, len(ordered) - 1)
    weight = rank - low
    return ordered[low] * (1 - weight) + ordered[high] * weight


def summarize(samples_s: list[float]) -> dict[str, float | int]:
    ms = [value * 1000 for value in samples_s]
    return {
        "n": len(ms),
        "median_ms": statistics.median(ms),
        "min_ms": min(ms),
        "max_ms": max(ms),
        "p95_ms": percentile(ms, 0.95),
        "mean_ms": statistics.fmean(ms),
        "samples_ms": ms,
    }


def fmt_ms(value: float) -> str:
    if value >= 100:
        return f"{value:.0f} ms"
    if value >= 10:
        return f"{value:.1f} ms"
    return f"{value:.2f} ms"


def fmt_size(num_bytes: int) -> str:
    if num_bytes >= 1024 * 1024:
        return f"{num_bytes / (1024 * 1024):.2f} MiB"
    return f"{num_bytes / 1024:.1f} KiB"


def read_meminfo() -> dict[str, int]:
    info: dict[str, int] = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        key, _, rest = line.partition(":")
        info[key] = int(rest.strip().split()[0])
    return info


def command_output(cmd: list[str]) -> str:
    result = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    return result.stdout.strip()


class BashSession:
    def __init__(self, env: dict[str, str], cwd: Path, prelude: str, log_path: Path):
        self.log_path = log_path
        self.err = log_path.open("w")
        self.buf = b""
        self.proc = subprocess.Popen(
            ["stdbuf", "-oL", "-eL", "bash", "--noprofile", "--norc"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.err,
            env=env,
            cwd=cwd,
            bufsize=0,
        )
        self._write(prelude + "\nprintf '%s\\n' __READY__\n")
        deadline = time.monotonic() + 90
        ready = ""
        while time.monotonic() < deadline:
            ready = self._read_line(max(1, deadline - time.monotonic()))
            if ready == "__READY__":
                break
        else:
            raise RuntimeError(f"prelude did not become ready ({ready!r}). log={log_path}")

    def close(self) -> None:
        if self.proc.poll() is None:
            self._write("exit 0\n")
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        self.err.close()

    def _write(self, text: str) -> None:
        assert self.proc.stdin is not None
        self.proc.stdin.write(text.encode())
        self.proc.stdin.flush()

    def _fill(self, deadline: float) -> None:
        assert self.proc.stdout is not None
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError(f"bash produced no output; log={self.log_path}")
        ready, _, _ = select.select([self.proc.stdout], [], [], min(remaining, 1))
        if not ready:
            if self.proc.poll() is not None:
                raise RuntimeError(f"bash exited {self.proc.returncode}; log={self.log_path}")
            return
        chunk = os.read(self.proc.stdout.fileno(), 65536)
        if not chunk:
            raise RuntimeError(f"bash closed stdout; log={self.log_path}")
        self.buf += chunk

    def _read_line(self, timeout: float) -> str:
        deadline = time.monotonic() + timeout
        while b"\n" not in self.buf:
            self._fill(deadline)
        line, self.buf = self.buf.split(b"\n", 1)
        return line.decode()

    def run(self, cmd: str, timeout: float = 120, timed: bool = True) -> tuple[float, int]:
        out = self.log_path.with_suffix(".cmd.out")
        err = self.log_path.with_suffix(".cmd.err")
        script = f"{{ {cmd}; }} >{out} 2>{err}\nprintf '__END__ %s\\n' $?\n"
        start = time.perf_counter()
        self._write(script)
        line = self._read_line(timeout)
        elapsed = time.perf_counter() - start
        if not line.startswith("__END__ "):
            raise RuntimeError(f"expected sentinel, got {line!r} for {cmd}")
        code = int(line.split()[1])
        if code != 0:
            err_text = err.read_text()[-2000:] if err.exists() else ""
            out_text = out.read_text()[-2000:] if out.exists() else ""
            raise RuntimeError(f"{cmd} exited {code}\nstdout:\n{out_text}\nstderr:\n{err_text}")
        return (elapsed if timed else 0.0), code


def bash_c(command: str, env: dict[str, str], cwd: Path, timeout: float = 60) -> tuple[float, subprocess.CompletedProcess[str]]:
    start = time.perf_counter()
    result = run(["bash", "--noprofile", "--norc", "-c", command], env, cwd, timeout)
    return time.perf_counter() - start, result


def adjust(raw: dict[str, float | int], harness_median_ms: float) -> dict[str, float | int]:
    samples = [float(value) - harness_median_ms for value in raw["samples_ms"]]  # type: ignore[index]
    return {
        "n": len(samples),
        "median_ms": statistics.median(samples),
        "min_ms": min(samples),
        "max_ms": max(samples),
        "p95_ms": percentile(samples, 0.95),
        "mean_ms": statistics.fmean(samples),
        "samples_ms": samples,
        "harness_median_ms": harness_median_ms,
    }


def measure_repeats(fn, warmup: int, samples: int) -> tuple[float, dict[str, float | int]]:
    first = fn()
    for _ in range(warmup):
        fn()
    measured = [fn() for _ in range(samples)]
    return first * 1000, summarize(measured)


def wipe(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)


def copy_nvm(src: Path, dest: Path) -> None:
    wipe(dest)
    shutil.copy(src / "nvm.sh", dest / "nvm.sh")


def find_nodes(root: Path) -> list[str]:
    found: list[str] = []
    if not root.exists():
        return found
    for dirpath, _, files in os.walk(root):
        if "node" in files and dirpath.endswith(f"{os.sep}bin"):
            found.append(str(Path(dirpath) / "node"))
    return found


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    log(f"download {url}")
    urllib.request.urlretrieve(url, dest)


def ensure_fnm(work: Path, explicit: str | None) -> Path:
    if explicit:
        path = Path(explicit)
        if not path.is_file():
            raise SystemExit(f"fnm binary not found: {path}")
        return path
    dest = work / "bin" / "fnm"
    if dest.is_file():
        return dest
    archive = work / "fnm-linux.zip"
    download(FNM_URL, archive)
    shutil.unpack_archive(archive, work / "bin")
    dest.chmod(0o755)
    return dest


def ensure_nvm_source(work: Path, explicit: str | None) -> Path:
    if explicit:
        path = Path(explicit)
        if not (path / "nvm.sh").is_file():
            raise SystemExit(f"nvm.sh not found under {path}")
        return path
    dest = work / "nvm-src"
    if (dest / "nvm.sh").is_file():
        return dest
    checked(
        ["git", "clone", "--depth", "1", "--branch", NVM_GIT, "https://github.com/nvm-sh/nvm.git", str(dest)],
        os.environ.copy(),
        work,
        timeout=120,
    )
    return dest


def content_length(version: str) -> int | None:
    url = f"{MIRROR}/v{version}/node-v{version}-linux-x64.tar.xz"
    request = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(request, timeout=60) as response:
        value = response.headers.get("Content-Length")
    return int(value) if value else None


def drop_caches() -> str | None:
    result = subprocess.run(
        ["sudo", "-n", "sh", "-c", "sync; echo 3 > /proc/sys/vm/drop_caches"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        return (result.stderr or result.stdout or "drop_caches failed").strip()
    return None


def shell_env(root_env: dict[str, str], tool: str, spec: dict[str, str]) -> dict[str, str]:
    env = dict(root_env)
    if tool == "znvm":
        env["ZNVM_DIR"] = spec["data"]
        env["PATH"] = f"{spec['bin_dir']}:/usr/bin:/bin"
    elif tool == "nvm":
        env["NVM_DIR"] = spec["data"]
        env["PATH"] = "/usr/bin:/bin"
    elif tool == "fnm":
        env["FNM_DIR"] = spec["data"]
        env["PATH"] = f"{spec['bin_dir']}:/usr/bin:/bin"
    return env


def prelude_for(tool: str, spec: dict[str, str], activate_node: bool) -> str:
    if tool == "znvm":
        return f'eval "$({spec["bin"]} env)"'
    if tool == "nvm":
        return f'source "{spec["data"]}/nvm.sh"'
    line = f'eval "$({spec["bin"]} env --use-on-cd --shell bash)"'
    if activate_node:
        line += f'\n{spec["bin"]} use {NODE_A}'
    return line


def setup_versions(tool: str, env: dict[str, str], cwd: Path, spec: dict[str, str]) -> None:
    log(f"installing Node {NODE_A} and {NODE_B} with {tool}")
    if tool == "znvm":
        binary = spec["bin"]
        checked([binary, "install", NODE_A], env, cwd, timeout=300)
        checked([binary, "install", NODE_B], env, cwd, timeout=300)
        checked([binary, "alias", "default", NODE_A], env, cwd)
    elif tool == "nvm":
        script = (
            f'source "{spec["data"]}/nvm.sh" && '
            f"nvm install {NODE_A} && nvm install {NODE_B} && nvm alias default {NODE_A}"
        )
        checked(["bash", "--noprofile", "--norc", "-c", script], env, cwd, timeout=300)
    elif tool == "fnm":
        binary = spec["bin"]
        checked([binary, "install", NODE_A], env, cwd, timeout=300)
        checked([binary, "install", NODE_B], env, cwd, timeout=300)
        checked([binary, "default", NODE_A], env, cwd)
    nodes = find_nodes(Path(spec["data"]))
    if len(nodes) < 2:
        raise SystemExit(f"{tool} installed {len(nodes)} node binaries, expected 2: {nodes}")


def clear_install_state(tool: str, spec: dict[str, str], nvm_src: Path, cache_dir: Path) -> None:
    data = Path(spec["data"])
    if tool == "nvm":
        copy_nvm(nvm_src, data)
    else:
        wipe(data)
    if cache_dir.exists():
        shutil.rmtree(cache_dir)


def active_node(command: str, env: dict[str, str], cwd: Path) -> str:
    elapsed, result = bash_c(command + "\nnode -v || echo NO_NODE", env, cwd, timeout=60)
    del elapsed
    if result.returncode != 0:
        return f"exit {result.returncode}: {(result.stderr or result.stdout)[-300:]}"
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return lines[-1] if lines else "NO_NODE"


def measure_tool_latency(tool: str, spec: dict[str, str], env: dict[str, str], neutral: Path, nvmrc_dir: Path, logs: Path, warmup: int, samples: int, startup_warmup: int, startup_samples: int) -> dict:
    log(f"latency: {tool}")
    documented = prelude_for(tool, spec, activate_node=False)
    comparable = prelude_for(tool, spec, activate_node=True)
    documented_node = active_node(documented, env, neutral)
    comparable_node = active_node(comparable, env, neutral)
    expected = f"v{NODE_A}"
    if comparable_node != expected:
        raise SystemExit(f"{tool} comparable init left node {comparable_node}, expected {expected}")

    session = BashSession(env, neutral, documented if tool != "fnm" else comparable, logs / f"{tool}-shell.log")
    try:
        def harness() -> float:
            elapsed, _ = session.run("true")
            return elapsed

        _, harness_stats = measure_repeats(harness, warmup=3, samples=20)
        harness_median = float(harness_stats["median_ms"])

        def once(cmd: str) -> float:
            elapsed, _ = session.run(cmd)
            return elapsed

        list_cmd = {"znvm": "znvm ls", "nvm": "nvm ls", "fnm": "fnm list"}[tool]
        use_bin = {"znvm": "znvm use", "nvm": "nvm use", "fnm": "fnm use"}[tool]
        versions = [NODE_B, NODE_A]
        counter = {"n": 0}

        def use_cmd() -> float:
            version = versions[counter["n"] % 2]
            counter["n"] += 1
            elapsed, _ = session.run(f"{use_bin} {version}")
            return elapsed

        list_first, list_raw = measure_repeats(lambda: once(list_cmd), warmup, samples)
        use_first, use_raw = measure_repeats(use_cmd, warmup, samples)

        def nvmrc_cmd() -> float:
            session.run(f"\\cd {nvmrc_dir} && {use_bin} {NODE_A}", timed=False)
            elapsed, _ = session.run(use_bin)
            return elapsed

        nvmrc_first, nvmrc_raw = measure_repeats(nvmrc_cmd, warmup, samples)
    finally:
        session.close()

    def startup(command: str) -> dict:
        def once_proc() -> float:
            elapsed, result = bash_c(command, env, neutral, timeout=60)
            if result.returncode != 0:
                raise RuntimeError(f"startup failed {result.returncode}: {result.stderr[-500:]}")
            return elapsed

        first, stats = measure_repeats(once_proc, startup_warmup, startup_samples)
        return {"first_ms": first, "raw": stats}

    startup_documented = startup(documented)
    startup_comparable = startup(comparable) if comparable != documented else startup_documented
    return {
        "commands": {
            "list": list_cmd,
            "use": f"{use_bin} {NODE_B} / {use_bin} {NODE_A} (alternating)",
            "nvmrc": f"{use_bin} with no args in a directory containing .nvmrc ({NODE_B})",
            "shell_init_documented": documented,
            "shell_init_node_active": comparable,
        },
        "node_after_documented_init": documented_node,
        "node_after_comparable_init": comparable_node,
        "harness_true": harness_stats,
        "list": {"first_raw_ms": list_first, "raw": list_raw, "adjusted": adjust(list_raw, harness_median)},
        "use": {"first_raw_ms": use_first, "raw": use_raw, "adjusted": adjust(use_raw, harness_median)},
        "nvmrc": {"first_raw_ms": nvmrc_first, "raw": nvmrc_raw, "adjusted": adjust(nvmrc_raw, harness_median)},
        "startup_documented": startup_documented,
        "startup_node_active": startup_comparable,
        "installed_nodes": find_nodes(Path(spec["data"])),
    }


def measure_install(tool: str, spec: dict[str, str], env: dict[str, str], cwd: Path, logs: Path, nvm_src: Path, repeats: int, cache_dir: Path) -> dict:
    log(f"install timing: {tool} x{repeats}")
    clear_install_state(tool, spec, nvm_src, cache_dir)
    session = BashSession(env, cwd, prelude_for(tool, spec, activate_node=False), logs / f"{tool}-install.log")
    samples: list[float] = []
    try:
        harness_samples: list[float] = []
        for _ in range(10):
            elapsed, _ = session.run("true")
            harness_samples.append(elapsed)
        harness_median = statistics.median(harness_samples) * 1000
        install_cmd = {"znvm": f"znvm install {NODE_INSTALL}", "nvm": f"nvm install {NODE_INSTALL}", "fnm": f"fnm install {NODE_INSTALL}"}[tool]
        for index in range(repeats):
            clear_install_state(tool, spec, nvm_src, cache_dir)
            log(f"  {tool} install sample {index + 1}")
            elapsed, _ = session.run(install_cmd, timeout=300)
            nodes = find_nodes(Path(spec["data"]))
            if not any(NODE_INSTALL in node for node in nodes):
                raise SystemExit(f"{tool} install reported success but {NODE_INSTALL} was not found under {spec['data']}: {nodes}")
            samples.append(elapsed)
    finally:
        session.close()
    raw = summarize(samples)
    return {"command": install_cmd, "raw": raw, "adjusted": adjust(raw, harness_median), "node_tarball": f"node-v{NODE_INSTALL}-linux-x64.tar.xz"}


def measure_cold(tool: str, spec: dict[str, str], env: dict[str, str], neutral: Path, nvmrc_dir: Path, logs: Path) -> dict:
    """One sample after dropping the page cache.

    Startup is a fresh bash. list/use/.nvmrc run in a shell that is already
    initialized, so those samples are cold file cache rather than cold process
    start. Each figure is a single sample.
    """
    comparable = prelude_for(tool, spec, activate_node=True)
    result: dict[str, float | str] = {"init": comparable, "samples": "1 (not a median)"}

    def one_process(command: str) -> float:
        error = drop_caches()
        if error:
            raise RuntimeError(error)
        elapsed, proc = bash_c(command, env, neutral, timeout=90)
        if proc.returncode != 0:
            raise RuntimeError(proc.stderr[-400:])
        return elapsed * 1000

    result["startup_node_active_ms"] = one_process(comparable)
    list_cmd = {"znvm": "znvm ls", "nvm": "nvm ls", "fnm": "fnm list"}[tool]
    use_bin = {"znvm": "znvm use", "nvm": "nvm use", "fnm": "fnm use"}[tool]
    session = BashSession(env, neutral, comparable, logs / f"{tool}-cold.log")
    try:
        def one_shell(command: str) -> float:
            error = drop_caches()
            if error:
                raise RuntimeError(error)
            elapsed, _ = session.run(command, timeout=90)
            return elapsed * 1000

        result["list_ms"] = one_shell(list_cmd)
        result["use_ms"] = one_shell(f"{use_bin} {NODE_B}")
        session.run(f"\\cd {nvmrc_dir} && {use_bin} {NODE_A}", timed=False)
        result["nvmrc_ms"] = one_shell(use_bin)
    finally:
        session.close()
    return result


def environment_record(znvm_bin: Path, fnm_bin: Path, nvm_sh: Path) -> dict:
    mem = read_meminfo()
    return {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "uname": command_output(["uname", "-a"]),
        "os_release": Path("/etc/os-release").read_text().strip(),
        "cpu": command_output(["bash", "-lc", "lscpu | sed -n '1,25p'"]),
        "mem_total_kib": mem.get("MemTotal"),
        "mem_available_kib": mem.get("MemAvailable"),
        "nproc": os.cpu_count(),
        "bash": command_output(["bash", "--version"]).splitlines()[0],
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "zig": command_output(["bash", "-lc", "command -v zig >/dev/null && zig version || true"]),
        "znvm_optimize": "ReleaseSafe",
        "znvm_bin": str(znvm_bin),
        "znvm_bytes": znvm_bin.stat().st_size,
        "fnm_bin": str(fnm_bin),
        "fnm_bytes": fnm_bin.stat().st_size,
        "fnm_version": command_output([str(fnm_bin), "--version"]),
        "nvm_sh": str(nvm_sh),
        "nvm_sh_bytes": nvm_sh.stat().st_size,
        "nvm_version": NVM_GIT,
        "mirror": MIRROR,
        "path_policy": "tool directory plus /usr/bin:/bin only",
        "git_head": command_output(["git", "rev-parse", "HEAD"]),
    }


def overhead(raw_stats: dict, baseline_median_ms: float) -> dict[str, float | int]:
    samples = [float(value) - baseline_median_ms for value in raw_stats["samples_ms"]]
    return {
        "n": len(samples),
        "median_ms": statistics.median(samples),
        "min_ms": min(samples),
        "max_ms": max(samples),
        "p95_ms": percentile(samples, 0.95),
        "mean_ms": statistics.fmean(samples),
        "samples_ms": samples,
        "baseline_median_ms": baseline_median_ms,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Measure znvm against nvm and fnm")
    parser.add_argument("--znvm-bin", required=True)
    parser.add_argument("--fnm-bin")
    parser.add_argument("--nvm-src")
    parser.add_argument("--work-dir", default="/tmp/znvm-bench-measure")
    parser.add_argument("--out", required=True)
    parser.add_argument("--warmup", type=int, default=10)
    parser.add_argument("--samples", type=int, default=40)
    parser.add_argument("--startup-warmup", type=int, default=5)
    parser.add_argument("--startup-samples", type=int, default=20)
    parser.add_argument("--install-samples", type=int, default=3)
    parser.add_argument("--skip-install", action="store_true")
    parser.add_argument("--skip-cold", action="store_true")
    args = parser.parse_args()

    work = Path(args.work_dir)
    home = work / "home"
    neutral = work / "neutral"
    nvmrc_dir = work / "nvmrc-project"
    logs = work / "logs"
    for path in (home, neutral, nvmrc_dir, logs):
        path.mkdir(parents=True, exist_ok=True)
    (nvmrc_dir / ".nvmrc").write_text(f"{NODE_B}\n")
    for name in (".node-version", "package.json"):
        leftover = nvmrc_dir / name
        if leftover.exists():
            leftover.unlink()

    znvm_bin = Path(args.znvm_bin).resolve()
    if not znvm_bin.is_file():
        raise SystemExit(f"missing znvm binary: {znvm_bin}")
    fnm_bin = ensure_fnm(work, args.fnm_bin).resolve()
    nvm_src = ensure_nvm_source(work, args.nvm_src)
    log(f"fnm {command_output([str(fnm_bin), '--version'])} nvm source {nvm_src}")

    root_env = {
        "PATH": "/usr/bin:/bin",
        "HOME": str(home),
        "LANG": "C",
        "LC_ALL": "C",
        "TERM": "dumb",
        "XDG_CACHE_HOME": str(home / ".cache"),
        "XDG_STATE_HOME": str(home / ".local" / "state"),
        "XDG_DATA_HOME": str(home / ".local" / "share"),
        "ZNVM_NODE_MIRROR": MIRROR,
        "NVM_NODEJS_ORG_MIRROR": MIRROR,
        "FNM_NODE_DIST_MIRROR": MIRROR,
    }
    specs = {
        "znvm": {"bin": str(znvm_bin), "bin_dir": str(znvm_bin.parent), "data": str(work / "data" / "znvm")},
        "nvm": {"bin": "", "bin_dir": "", "data": str(work / "data" / "nvm")},
        "fnm": {"bin": str(fnm_bin), "bin_dir": str(fnm_bin.parent), "data": str(work / "data" / "fnm")},
    }
    install_specs = {
        "znvm": {"bin": str(znvm_bin), "bin_dir": str(znvm_bin.parent), "data": str(work / "install-data" / "znvm")},
        "nvm": {"bin": "", "bin_dir": "", "data": str(work / "install-data" / "nvm")},
        "fnm": {"bin": str(fnm_bin), "bin_dir": str(fnm_bin.parent), "data": str(work / "install-data" / "fnm")},
    }
    if not (Path(specs["nvm"]["data"]) / "nvm.sh").is_file():
        copy_nvm(nvm_src, Path(specs["nvm"]["data"]))
    for tool in TOOLS:
        data = Path(specs[tool]["data"])
        data.mkdir(parents=True, exist_ok=True)
        if len(find_nodes(data)) >= 2:
            log(f"reusing installed Node versions for {tool}")
            continue
        if tool != "nvm":
            wipe(data)
        setup_versions(tool, shell_env(root_env, tool, specs[tool]), neutral, specs[tool])

    tarball_bytes = content_length(NODE_INSTALL)
    log(f"install tarball content-length {tarball_bytes}")

    latency = {}
    for tool in TOOLS:
        latency[tool] = measure_tool_latency(
            tool,
            specs[tool],
            shell_env(root_env, tool, specs[tool]),
            neutral,
            nvmrc_dir,
            logs,
            args.warmup,
            args.samples,
            args.startup_warmup,
            args.startup_samples,
        )

    # Baseline process startup, same PATH policy and cwd, no version manager.
    baseline_env = dict(root_env)
    baseline_env["PATH"] = "/usr/bin:/bin"

    def baseline_once() -> float:
        elapsed, result = bash_c("true", baseline_env, neutral)
        if result.returncode != 0:
            raise RuntimeError(result.stderr)
        return elapsed

    baseline_first, baseline_stats = measure_repeats(baseline_once, args.startup_warmup, args.startup_samples)
    baseline_median = float(baseline_stats["median_ms"])
    for tool in TOOLS:
        for key in ("startup_documented", "startup_node_active"):
            latency[tool][key]["overhead"] = overhead(latency[tool][key]["raw"], baseline_median)

    installs = {}
    if not args.skip_install:
        for tool in TOOLS:
            installs[tool] = measure_install(
                tool,
                install_specs[tool],
                shell_env(root_env, tool, install_specs[tool]),
                neutral,
                logs,
                nvm_src,
                args.install_samples,
                Path(root_env["XDG_CACHE_HOME"]),
            )

    cold: dict[str, dict | str] = {}
    if args.skip_cold:
        cold = {"skipped": "not requested"}
    else:
        error = drop_caches()
        if error:
            cold = {"available": False, "error": error}
            log(f"drop_caches unavailable: {error}")
        else:
            cold = {"available": True, "note": "one sample per figure after sync and drop_caches; not a median"}
            for tool in TOOLS:
                log(f"cold samples: {tool}")
                cold[tool] = measure_cold(
                    tool,
                    specs[tool],
                    shell_env(root_env, tool, specs[tool]),
                    neutral,
                    nvmrc_dir,
                    logs,
                )

    payload = {
        "method": Path(__file__).read_text().split('"""', 2)[1].strip(),
        "parameters": {
            "warmup": args.warmup,
            "samples": args.samples,
            "startup_warmup": args.startup_warmup,
            "startup_samples": args.startup_samples,
            "install_samples": args.install_samples,
            "latency_versions": [NODE_A, NODE_B],
            "default_version": NODE_A,
            "nvmrc": NODE_B,
            "install_version": NODE_INSTALL,
            "install_tarball_bytes": tarball_bytes,
        },
        "environment": environment_record(znvm_bin, fnm_bin, nvm_src / "nvm.sh"),
        "baseline_bash_true": {"first_ms": baseline_first, "raw": baseline_stats},
        "latency": latency,
        "install": installs,
        "cold": cold,
        "sizes": {
            "znvm_binary": {"bytes": znvm_bin.stat().st_size, "display": fmt_size(znvm_bin.stat().st_size)},
            "fnm_binary": {"bytes": fnm_bin.stat().st_size, "display": fmt_size(fnm_bin.stat().st_size)},
            "nvm_sh": {"bytes": (nvm_src / "nvm.sh").stat().st_size, "display": fmt_size((nvm_src / "nvm.sh").stat().st_size) + " script"},
        },
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n")
    log(f"wrote {out}")
    print_summary(payload)


def print_summary(payload: dict) -> None:
    sizes = payload["sizes"]
    log("")
    log("sizes: " + ", ".join(f"{name}={info['display']}" for name, info in sizes.items()))
    log(f"baseline bash -c true median {fmt_ms(payload['baseline_bash_true']['raw']['median_ms'])}")
    log(f"{'tool':<6} {'list':>10} {'use':>10} {'nvmrc':>10} {'startup':>10} {'startup p95':>12}")
    for tool in TOOLS:
        item = payload["latency"][tool]
        startup = item["startup_node_active"]["overhead"]
        log(
            f"{tool:<6} "
            f"{fmt_ms(item['list']['adjusted']['median_ms']):>10} "
            f"{fmt_ms(item['use']['adjusted']['median_ms']):>10} "
            f"{fmt_ms(item['nvmrc']['adjusted']['median_ms']):>10} "
            f"{fmt_ms(startup['median_ms']):>10} "
            f"{fmt_ms(startup['p95_ms']):>12}"
        )
    if payload["install"]:
        log("install medians (cache cleared, includes download):")
        for tool in TOOLS:
            log(f"  {tool}: {fmt_ms(payload['install'][tool]['adjusted']['median_ms'])}")
    log(f"documented init node: " + ", ".join(
        f"{tool}={payload['latency'][tool]['node_after_documented_init']}" for tool in TOOLS
    ))


if __name__ == "__main__":
    main()
