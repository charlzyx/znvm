"use client";

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

interface BenchmarkProps {
  lang?: "en" | "zh";
}

export function Benchmark({ lang = "en" }: BenchmarkProps) {
  const isZh = lang === "zh";

  const data = [
    { name: "nvm", list: "708ms", use: "192ms", nvmrc: "189ms", binary: "N/A" },
    { name: "fnm", list: "6ms", use: "4ms", nvmrc: "10ms", binary: "~8MB" },
    { name: "znvm", list: "4ms", use: "3ms", nvmrc: "2ms", binary: "< 1MB", highlight: true },
  ];

  return (
    <section className="py-20">
      <div className="container">
        <div className="mx-auto max-w-3xl">
          <div className="text-center mb-8">
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              {isZh ? "性能对比" : "Performance Comparison"}
            </h2>
            <p className="mt-4 text-muted-foreground">
              {isZh
                ? "在 Apple M4 (16GB 内存, macOS 25.3) 上的真实基准测试"
                : "Actual benchmark on Apple M4 (16GB RAM, macOS 25.3)"
              }
            </p>
          </div>

          <Card>
            <CardContent className="p-0">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[100px]">{isZh ? "管理器" : "Manager"}</TableHead>
                    <TableHead className="text-right">{isZh ? "列出 (list)" : "list"}</TableHead>
                    <TableHead className="text-right">{isZh ? "切换 (use)" : "use"}</TableHead>
                    <TableHead className="text-right">.nvmrc</TableHead>
                    <TableHead className="text-right">{isZh ? "二进制" : "Binary"}</TableHead>
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
                        {row.binary}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>

          <p className="mt-4 text-center text-sm text-muted-foreground">
            {isZh
              ? "znvm 在所有操作中都显著更快，同时保持极小的二进制文件大小"
              : "znvm is significantly faster across all operations while maintaining a minimal binary size"
            }
          </p>
        </div>
      </div>
    </section>
  );
}
