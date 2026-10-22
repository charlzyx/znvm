"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Zap,
  Target,
  Box,
  Plug
} from "lucide-react";

interface FeaturesProps {
  lang?: "en" | "zh";
}

export function Features({ lang = "en" }: FeaturesProps) {
  const isZh = lang === "zh";

  const features = [
    {
      icon: Zap,
      title: isZh ? "Zig 驱动的极速" : "Zig-Powered Speed",
      description: isZh
        ? "基于 Zig 的零成本抽象和显式内存控制构建。无运行时开销，无垃圾回收停顿。"
        : "Built with Zig's zero-cost abstractions and explicit memory control. No runtime overhead, no garbage collection pauses.",
    },
    {
      icon: Target,
      title: isZh ? "Unix 哲学" : "Unix Philosophy",
      description: isZh
        ? "做一件事，并做好它。znvm 专注于 macOS 和 Linux，利用原生系统调用，而非跨平台妥协。"
        : "Do one thing and do it well. znvm focuses exclusively on macOS and Linux, leveraging native system calls instead of cross-platform compromises.",
    },
    {
      icon: Box,
      title: isZh ? "零依赖" : "Zero Dependencies",
      description: isZh
        ? "单个静态二进制文件。无运行时，无包管理器依赖，无意外。"
        : "Single static binary. No runtime, no package manager dependencies, no surprises.",
    },
    {
      icon: Plug,
      title: isZh ? "即插即用" : "Drop-in Replacement",
      description: isZh
        ? "安装后的命令是 nvm，版本放在 ~/.nvm。在终端里不带参数运行 nvm 会打开交互引导。"
        : "Installs as nvm and stores versions in ~/.nvm. In a terminal, nvm with no arguments opens an interactive guide.",
    },
  ];

  return (
    <section className="py-20 bg-muted/50">
      <div className="container">
        <div className="mx-auto max-w-2xl text-center mb-12">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            {isZh ? "为什么选择 znvm?" : "Why znvm?"}
          </h2>
          <p className="mt-4 text-lg text-muted-foreground">
            {isZh
              ? "znvm = Zig + nvm。名字说明一切。"
              : "znvm = Zig + nvm. The name says it all."
            }
          </p>
        </div>

        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {features.map((feature) => (
            <Card key={feature.title} className="border-0 bg-background/50">
              <CardHeader>
                <feature.icon className="h-8 w-8 text-orange-500 mb-2" />
                <CardTitle className="text-lg">{feature.title}</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">
                  {feature.description}
                </p>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}
