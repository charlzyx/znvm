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

function PhoneStats({
  name,
  highlight,
  rows,
}: {
  name: string;
  highlight?: boolean;
  rows: { label: string; value: string; accent?: boolean }[];
}) {
  return (
    <article className={`border-b border-border p-4 last:border-b-0 ${highlight ? "bg-node/10" : ""}`}>
      <p className="font-semibold">
        {highlight ? <Badge className="bg-node text-[#041208]">{name}</Badge> : name}
      </p>
      <dl className="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
        {rows.map((row) => (
          <div key={row.label}>
            <dt className="text-muted-foreground">{row.label}</dt>
            <dd className={`tabular-nums ${row.accent ? "font-semibold text-zig" : ""}`}>{row.value}</dd>
          </div>
        ))}
      </dl>
    </article>
  );
}

function NameCell({ name, highlight }: { name: string; highlight?: boolean }) {
  return (
    <TableCell className="font-medium">
      {highlight ? <Badge className="bg-node text-[#041208]">{name}</Badge> : name}
    </TableCell>
  );
}

export function Benchmark({ lang = "en" }: BenchmarkProps) {
  const isZh = lang === "zh";

  return (
    <section className="py-12 sm:py-16">
      <div className="container">
        <div>
          <h2 className="text-3xl font-semibold tracking-[-0.03em] sm:text-4xl">
            {isZh ? "速度" : "Speed"}
          </h2>
          <p className="mt-5 text-5xl font-semibold tracking-[-0.04em] text-zig sm:text-6xl">3.31 ms</p>
          <p className="mt-2 text-lg text-muted-foreground">
            {isZh ? "暖 shell 启动，2026-10-22" : "Warm shell startup, 2026-10-22"}
          </p>
          <p className="mt-4 max-w-[65ch] text-base text-foreground">
            {isZh
              ? "15:38-15:40 UTC，中位数。4 核 KVM（Intel Xeon），Ubuntu 24.04。benchmarks/measure.py。znvm ReleaseSafe，3.73 MiB。"
              : "Medians, 15:38-15:40 UTC. 4-vCPU KVM (Intel Xeon), Ubuntu 24.04. benchmarks/measure.py. znvm ReleaseSafe, 3.73 MiB."
            }
          </p>

          <h3 className="mb-3 mt-14 text-2xl font-semibold">
            {isZh ? "Shell 启动" : "Shell startup"}
          </h3>
          <div className="mb-8 border border-border md:hidden">
            {startup.map((row) => (
              <PhoneStats
                key={row.name}
                name={row.name}
                highlight={row.highlight}
                rows={[
                  { label: isZh ? "暖中位数" : "Warm median", value: row.warm, accent: row.highlight },
                  { label: isZh ? "暖 p95" : "Warm p95", value: row.warmP95 },
                  { label: isZh ? "冷中位数" : "Cold median", value: row.cold },
                  { label: isZh ? "冷 p95" : "Cold p95", value: row.coldP95 },
                ]}
              />
            ))}
          </div>
          <Card className="mb-8 hidden min-w-0 border border-border shadow-none ring-0 md:flex">
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
                    <TableRow key={row.name} className={row.highlight ? "bg-node/10" : ""}>
                      <NameCell name={row.name} highlight={row.highlight} />
                      <TableCell className={`text-right tabular-nums ${row.highlight ? "text-lg font-semibold text-zig" : ""}`}>{row.warm}</TableCell>
                      <TableCell className="text-right tabular-nums">{row.warmP95}</TableCell>
                      <TableCell className="text-right tabular-nums">{row.cold}</TableCell>
                      <TableCell className="text-right tabular-nums">{row.coldP95}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>

          <h3 className="mb-3 mt-12 text-2xl font-semibold">
            {isZh ? "Shell 内命令" : "In-shell commands"}
          </h3>
          <div className="border border-border md:hidden">
            {commands.map((row) => (
              <PhoneStats
                key={row.name}
                name={row.name}
                highlight={row.highlight}
                rows={[
                  { label: isZh ? "list 暖" : "list warm", value: row.listWarm, accent: row.highlight },
                  { label: isZh ? "list 冷" : "list cold", value: row.listCold },
                  { label: isZh ? "use 暖" : "use warm", value: row.useWarm },
                  { label: isZh ? "use 冷" : "use cold", value: row.useCold },
                  { label: isZh ? ".nvmrc 暖" : ".nvmrc warm", value: row.nvmrcWarm },
                  { label: isZh ? ".nvmrc 冷" : ".nvmrc cold", value: row.nvmrcCold },
                ]}
              />
            ))}
          </div>
          <Card className="hidden min-w-0 border border-border shadow-none ring-0 md:flex">
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
                    <TableRow key={row.name} className={row.highlight ? "bg-node/10" : ""}>
                      <NameCell name={row.name} highlight={row.highlight} />
                      <TableCell className="text-right tabular-nums">{row.highlight ? <strong>{row.listWarm}</strong> : row.listWarm}</TableCell>
                      <TableCell className="text-right tabular-nums">{row.highlight ? <strong>{row.listCold}</strong> : row.listCold}</TableCell>
                      <TableCell className="text-right tabular-nums">{row.highlight ? <strong>{row.useWarm}</strong> : row.useWarm}</TableCell>
                      <TableCell className="text-right tabular-nums">{row.highlight ? <strong>{row.useCold}</strong> : row.useCold}</TableCell>
                      <TableCell className="text-right tabular-nums">{row.highlight ? <strong>{row.nvmrcWarm}</strong> : row.nvmrcWarm}</TableCell>
                      <TableCell className="text-right tabular-nums">{row.highlight ? <strong>{row.nvmrcCold}</strong> : row.nvmrcCold}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>

          <p className="mt-4 max-w-[65ch] text-sm text-muted-foreground">
            {isZh
              ? "暖启动 20 次（预热 5 次），减去 bash -c true（0.63 ms）。冷启动 20 次，每次丢掉页缓存，减去 bash -c true（2.02 ms）。命令：暖 40 次，冷 20 次。这次 shell 启动 fnm 更快；list、use、.nvmrc 是 znvm 更快。样本：benchmarks/results/2026-10-22-cold-warm.json。"
              : "Warm startup: 20 samples after 5 warmup, minus bash -c true (0.63 ms). Cold startup: 20 samples after a page-cache drop, minus bash -c true (2.02 ms). Commands: warm 40, cold 20. On this run fnm started the shell faster. znvm was faster at list, use, and .nvmrc. Samples: benchmarks/results/2026-10-22-cold-warm.json."
            }
          </p>
        </div>
      </div>
    </section>
  );
}
