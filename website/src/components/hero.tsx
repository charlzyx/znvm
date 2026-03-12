"use client";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  Zap,
  ArrowRight,
  Github,
  Copy,
  Check
} from "lucide-react";
import Link from "next/link";
import { useState } from "react";

interface HeroProps {
  lang?: "en" | "zh";
}

export function Hero({ lang = "en" }: HeroProps) {
  const isZh = lang === "zh";
  const [copied, setCopied] = useState(false);
  const installCmd = "curl -fsSL https://znvm.dev/install.sh | bash";

  const copyToClipboard = () => {
    navigator.clipboard.writeText(installCmd);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <section className="relative overflow-hidden">
      {/* Background gradient */}
      <div className="absolute inset-0 bg-gradient-to-br from-orange-500/5 via-background to-background" />

      <div className="container relative py-20 lg:py-32">
        <div className="mx-auto flex max-w-3xl flex-col items-center text-center">
          {/* Badge */}
          <Badge variant="secondary" className="mb-4">
            <Zap className="mr-1 h-3 w-3 text-orange-500" />
            {isZh ? "基于 Zig 构建" : "Built with Zig"}
          </Badge>

          {/* Title */}
          <h1 className="text-4xl font-bold tracking-tight sm:text-5xl md:text-6xl lg:text-7xl">
            <span className="text-orange-500">znvm</span>
            <span className="text-muted-foreground text-lg sm:text-xl font-normal ml-4 tracking-normal">
              {isZh ? "— Zig 驱动的 NVM" : "— The Zig-powered NVM"}
            </span>
          </h1>

          {/* Description */}
          <p className="mt-6 max-w-[700px] text-lg text-muted-foreground sm:text-xl">
            {isZh
              ? "零负担 Node 版本管理器。终极 nvm 替代品，解决 nvm 卡顿问题。< 5ms 启动，Unix 优先，零配置。"
              : "Zero-overhead Node Version Manager. The ultimate nvm alternative that solves the nvm-slow problem. < 5ms startup, Unix-first, zero config."
            }
          </p>

          {/* CTA Buttons */}
          <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
            <Link href={isZh ? "/zh/getting-started" : "/getting-started"}>
              <Button size="lg" className="bg-orange-500 hover:bg-orange-600">
                {isZh ? "快速开始" : "Get Started"}
                <ArrowRight className="ml-2 h-4 w-4" />
              </Button>
            </Link>
            <Link href="https://github.com/charlzyx/znvm" target="_blank">
              <Button variant="outline" size="lg">
                <Github className="mr-2 h-4 w-4" />
                GitHub
              </Button>
            </Link>
          </div>

          {/* Install Command */}
          <Card className="mt-8 w-full max-w-lg">
            <CardContent className="flex items-center justify-between p-4">
              <code className="text-sm font-mono text-muted-foreground">
                {installCmd}
              </code>
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8"
                onClick={copyToClipboard}
              >
                {copied ? <Check className="h-4 w-4 text-green-500" /> : <Copy className="h-4 w-4" />}
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </section>
  );
}
