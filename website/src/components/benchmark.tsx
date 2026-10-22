"use client";

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

interface BenchmarkProps {
  lang?: "en" | "zh";
}

const startup = [
  { name: "nvm", warm: "113 ms", warmP95: "115 ms", cold: "121 ms", coldP95: "128 ms" },
  { name: "fnm", warm: "1.58 ms", warmP95: "1.76 ms", cold: "4.70 ms", coldP95: "6.67 ms" },
  { name: "znvm", warm: "3.31 ms", warmP95: "3.64 ms", cold: "5.01 ms", coldP95: "9.28 ms", highlight: true },
];

const commands = [
  { name: "nvm", listWarm: "559 ms", listCold: "557 ms", useWarm: "158 ms", useCold: "221 ms", nvmrcWarm: "166 ms", nvmrcCold: "222 ms" },
  { name: "fnm", listWarm: "1.26 ms", listCold: "6.10 ms", useWarm: "1.35 ms", useCold: "6.19 ms", nvmrcWarm: "1.41 ms", nvmrcCold: "5.20 ms" },
  { name: "znvm", listWarm: "0.61 ms", listCold: "3.18 ms", useWarm: "0.84 ms", useCold: "3.44 ms", nvmrcWarm: "0.86 ms", nvmrcCold: "3.06 ms", highlight: true },
];

function NameCell({ name, highlight }: { name: string; highlight?: boolean }) {
  return (
    <TableCell className="font-medium">
      {highlight ? <Badge className="bg-orange-500">{name}</Badge> : name}
    </TableCell>
  );
}

export function Benchmark({ lang = "en" }: BenchmarkProps) {
  const isZh = lang === "zh";

  return (
    <section className="py-20">
      <div className="container">
        <div className="mx-auto max-w-4xl">
          <div className="text-center mb-8">
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              {isZh ? "性能对比" : "Performance Comparison"}
            </h2>
            <p className="mt-4 text-muted-foreground">
              {isZh
                ? "2026-10-22 15:38–15:40 UTC，同一次运行里的暖启动和冷启动中位数。4 核 KVM（lscpu：Intel Xeon），Ubuntu 24.04。方法：benchmarks/measure.py。znvm 为 ReleaseSafe，3.73 MiB。"
                : "Warm and cold medians from one run, 2026-10-22 15:38–15:40 UTC. 4-vCPU KVM guest (lscpu: Intel Xeon), Ubuntu 24.04. Method: benchmarks/measure.py. znvm ReleaseSafe, 3.73 MiB."
              }
            </p>
          </div>

          <h3 className="mb-3 text-lg font-semibold">
            {isZh ? "Shell 启动（新 bash，减去 bash -c true）" : "Shell startup (new bash, minus bash -c true)"}
          </h3>
          <Card className="mb-8">
            <CardContent className="p-0 overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{isZh ? "管理器" : "Manager"}</TableHead>
                    <TableHead className="text-right">{isZh ? "暖 中位数" : "Warm median"}</TableHead>
                    <TableHead className="text-right">{isZh ? "暖 p95" : "Warm p95"}</TableHead>
                    <TableHead className="text-right">{isZh ? "冷 中位数" : "Cold median"}</TableHead>
                    <TableHead className="text-right">{isZh ? "冷 p95" : "Cold p95"}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {startup.map((row) => (
                    <TableRow key={row.name} className={row.highlight ? "bg-orange-500/5" : ""}>
                      <NameCell name={row.name} highlight={row.highlight} />
                      <TableCell className="text-right font-mono">{row.warm}</TableCell>
                      <TableCell className="text-right font-mono">{row.warmP95}</TableCell>
                      <TableCell className="text-right font-mono">{row.cold}</TableCell>
                      <TableCell className="text-right font-mono">{row.coldP95}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>

          <h3 className="mb-3 text-lg font-semibold">
            {isZh ? "已打开的 shell 里的命令" : "Commands in an already-open shell"}
          </h3>
          <Card>
            <CardContent className="p-0 overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{isZh ? "管理器" : "Manager"}</TableHead>
                    <TableHead className="text-right">{isZh ? "list 暖" : "list warm"}</TableHead>
                    <TableHead className="text-right">{isZh ? "list 冷" : "list cold"}</TableHead>
                    <TableHead className="text-right">{isZh ? "use 暖" : "use warm"}</TableHead>
                    <TableHead className="text-right">{isZh ? "use 冷" : "use cold"}</TableHead>
                    <TableHead className="text-right">{isZh ? ".nvmrc 暖" : ".nvmrc warm"}</TableHead>
                    <TableHead className="text-right">{isZh ? ".nvmrc 冷" : ".nvmrc cold"}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {commands.map((row) => (
                    <TableRow key={row.name} className={row.highlight ? "bg-orange-500/5" : ""}>
                      <NameCell name={row.name} highlight={row.highlight} />
                      <TableCell className="text-right font-mono">{row.highlight ? <strong>{row.listWarm}</strong> : row.listWarm}</TableCell>
                      <TableCell className="text-right font-mono">{row.highlight ? <strong>{row.listCold}</strong> : row.listCold}</TableCell>
                      <TableCell className="text-right font-mono">{row.highlight ? <strong>{row.useWarm}</strong> : row.useWarm}</TableCell>
                      <TableCell className="text-right font-mono">{row.highlight ? <strong>{row.useCold}</strong> : row.useCold}</TableCell>
                      <TableCell className="text-right font-mono">{row.highlight ? <strong>{row.nvmrcWarm}</strong> : row.nvmrcWarm}</TableCell>
                      <TableCell className="text-right font-mono">{row.highlight ? <strong>{row.nvmrcCold}</strong> : row.nvmrcCold}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>

          <p className="mt-4 text-sm text-muted-foreground">
            {isZh
              ? "暖 shell 启动：预热 5 次后采样 20 次，减去暖的 bash -c true（中位数 0.63 ms）。冷 shell 启动：20 次，每次先 sync 并丢掉页缓存，再开新 bash，减去同样条件下的 bash -c true（中位数 2.02 ms）。list / use / .nvmrc 的暖值是已初始化 shell 里预热 10 次、采样 40 次。冷的命令样本丢掉文件缓存，但 shell 进程还在。这次 n=20 或 40 时，p50 等于中位数。fnm 的文档化 init 已经激活 Node v22.14.0；暖运行里多一次 fnm use 是 2.50 ms，没有放进表里。这次 shell 启动（暖、冷）都是 fnm 低于 znvm，两者都低于 nvm。shell 内命令（暖、冷）是 znvm 更低。p95 和每个样本在 benchmarks/results/2026-10-22-cold-warm.json。更早一次只有暖启动中位数、外加单次冷样本，以及安装耗时，在 benchmarks/results/2026-10-22.json（安装 Node 22.13.1，含下载，3 次：znvm 1241 ms，fnm 2317 ms，nvm 2327 ms，主要是网络）。"
              : "Warm shell startup: 20 samples after 5 warmup, minus warm bash -c true (median 0.63 ms). Cold shell startup: 20 samples, each after sync and a page-cache drop, then a new bash, minus bash -c true measured the same way (median 2.02 ms). Warm list / use / .nvmrc: 40 samples after 10 warmup in an already-initialized shell. Cold command samples drop the file cache and keep that shell. At these sample counts, p50 equals the median. fnm's documented init already had Node v22.14.0 active; an extra warm fnm use was 2.50 ms and is not shown. On this run, warm and cold shell startup were lower for fnm than znvm, and both were lower than nvm. Warm and cold in-shell commands were lower for znvm. p95 and every sample: benchmarks/results/2026-10-22-cold-warm.json. An earlier warm-only run, one cold sample, and the install timing are in benchmarks/results/2026-10-22.json (Node 22.13.1, download included, 3 samples: znvm 1241 ms, fnm 2317 ms, nvm 2327 ms, mostly network)."
            }
          </p>
        </div>
      </div>
    </section>
  );
}
