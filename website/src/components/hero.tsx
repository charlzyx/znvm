"use client";

import Link from "next/link";
import { ArrowRight, Github } from "lucide-react";
import { Button } from "@/components/ui/button";
import { TypingTerminal } from "@/components/typing-terminal";

export function Hero({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";

  return (
    <section className="relative overflow-hidden border-b-4 border-zig">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(51,153,51,0.22),transparent_55%)]" />
      <div className="container relative py-20 sm:py-28 lg:py-32">
        <div className="grid items-center gap-14 lg:grid-cols-2 lg:gap-16">
          <div>
            <p className="zig-mark">{zh ? "用 Zig 构建" : "Built with Zig"}</p>
            <h1 className="mt-6 text-6xl font-bold leading-none tracking-tighter sm:text-7xl lg:text-8xl">
              znvm
            </h1>
            <p className="mt-6 max-w-xl text-xl text-muted-foreground sm:text-2xl">
              {zh
                ? "命令是 nvm 和 nrm。版本在 ~/.nvm。Node 从 npmmirror 下载。"
                : "Commands are nvm and nrm. Versions live in ~/.nvm. Node downloads come from npmmirror."}
            </p>
            <div className="mt-10 flex flex-wrap gap-3">
              <Link href={zh ? "/zh/getting-started" : "/getting-started"}>
                <Button size="lg" className="h-12 bg-node px-6 text-base text-[#041208] hover:bg-[#43a843]">
                  {zh ? "快速开始" : "Quick start"}
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </Link>
              <a href="https://znvm.dev/llm.txt">
                <Button size="lg" variant="outline" className="h-12 border-foreground/25 bg-transparent px-6 text-base">
                  {zh ? "给 Agent" : "For Agents"}
                </Button>
              </a>
              <Link href="https://github.com/charlzyx/znvm" target="_blank" rel="noopener noreferrer">
                <Button size="lg" variant="outline" className="h-12 border-foreground/25 bg-transparent px-6 text-base">
                  <Github className="mr-2 h-4 w-4" />
                  GitHub
                </Button>
              </Link>
            </div>
          </div>
          <TypingTerminal />
        </div>
      </div>
    </section>
  );
}
