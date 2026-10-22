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

export function Benchmark({ lang = "en" }: BenchmarkProps) {
  const isZh = lang === "zh";

  const data = [
    { name: "nvm", startup: "118 ms", list: "527 ms", use: "153 ms", nvmrc: "166 ms", size: "146.7 KiB script" },
    { name: "fnm", startup: "1.58 ms", list: "1.31 ms", use: "1.46 ms", nvmrc: "1.43 ms", size: "7.03 MiB" },
    { name: "znvm", startup: "3.55 ms", list: "0.62 ms", use: "0.89 ms", nvmrc: "0.97 ms", size: "3.73 MiB", highlight: true },
  ];

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
                ? "2026-10-22 测得的暖机中位数。4 核 KVM 虚拟机（lscpu 报 Intel Xeon），Ubuntu 24.04。方法：benchmarks/measure.py。znvm 为 ReleaseSafe。"
                : "Warm medians measured 2026-10-22. 4-vCPU KVM guest (lscpu: Intel Xeon), Ubuntu 24.04. Method: benchmarks/measure.py. znvm built ReleaseSafe."
              }
            </p>
          </div>

          <Card>
            <CardContent className="p-0">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[100px]">{isZh ? "管理器" : "Manager"}</TableHead>
                    <TableHead className="text-right">{isZh ? "shell 启动" : "shell startup"}</TableHead>
                    <TableHead className="text-right">{isZh ? "列出 (list)" : "list"}</TableHead>
                    <TableHead className="text-right">{isZh ? "切换 (use)" : "use"}</TableHead>
                    <TableHead className="text-right">.nvmrc</TableHead>
                    <TableHead className="text-right">{isZh ? "体积" : "Size"}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data.map((row) => (
                    <TableRow
                      key={row.name}
                      className={row.highlight ? "bg-orange-500/5" : ""}
                    >
                      <TableCell className="font-medium">
                        {row.highlight ? (
                          <Badge className="bg-orange-500">{row.name}</Badge>
                        ) : (
                          row.name
                        )}
                      </TableCell>
                      <TableCell className="text-right font-mono">{row.startup}</TableCell>
                      <TableCell className="text-right font-mono">
                        {row.highlight ? <strong>{row.list}</strong> : row.list}
                      </TableCell>
                      <TableCell className="text-right font-mono">
                        {row.highlight ? <strong>{row.use}</strong> : row.use}
                      </TableCell>
                      <TableCell className="text-right font-mono">
                        {row.highlight ? <strong>{row.nvmrc}</strong> : row.nvmrc}
                      </TableCell>
                      <TableCell className="text-right font-mono text-muted-foreground">
                        {row.size}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>

          <p className="mt-4 text-center text-sm text-muted-foreground">
            {isZh
              ? "list / use / .nvmrc 是已初始化 shell 内的耗时（预热 10 次，采样 40 次）。shell 启动是新 bash 减去 bash -c true（预热 5 次，采样 20 次）。fnm 的文档化 init 在这次运行里已经激活了 Node v22.14.0，所以表中是 1.58 ms；额外再执行一次 fnm use 是 2.43 ms，没有放进表里。这次 znvm 的命令延迟更低；shell 启动低于 nvm、高于 fnm。从 nodejs.org 安装 Node 22.13.1（清缓存，含下载，3 次）：znvm 1241 ms，fnm 2317 ms，nvm 2327 ms。安装耗时主要是网络，不能当成稳定倍数。冷启动单次样本只在 benchmarks/results/2026-10-22.json 里。"
              : "list / use / .nvmrc are inside an already-initialized shell (10 warmup, 40 samples). Shell startup is a fresh bash minus bash -c true (5 warmup, 20 samples). fnm's documented init already had Node v22.14.0 active on this run, so the table uses 1.58 ms; an extra fnm use was 2.43 ms and is not shown. znvm's command latency was lower here. Its shell startup was lower than nvm and higher than fnm. Installing Node 22.13.1 from nodejs.org (cache cleared, download included, 3 samples): znvm 1241 ms, fnm 2317 ms, nvm 2327 ms. Install time is mostly network, so that gap is not a stable multiplier. Single cold samples are only in benchmarks/results/2026-10-22.json."
            }
          </p>
        </div>
      </div>
    </section>
  );
}
