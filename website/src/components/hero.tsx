"use client";

import Link from "next/link";
import { ArrowRight, Github } from "lucide-react";
import { Button } from "@/components/ui/button";
import { TypingTerminal } from "@/components/typing-terminal";

export function Hero({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";

  return (
    <section className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(51,153,51,0.22),transparent_55%)]" />
      <div className="container relative py-16 sm:py-24">
        <div className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)]">
          <div>
            <p className="text-xs font-medium uppercase tracking-[0.22em] text-node-bright">
              {zh ? "Zig 写的 nvm" : "nvm, written in Zig"}
            </p>
            <h1 className="mt-4 text-5xl font-bold tracking-tight sm:text-6xl">
              znvm
            </h1>
            <p className="mt-5 max-w-xl text-lg text-muted-foreground">
              {zh
                ? "安装之后的命令是 nvm。版本放在 ~/.nvm。Node 默认从 npmmirror 下载。不带参数打开交互引导，也可以按 scope 把源写进 npm、yarn、pnpm 和 bun。"
                : "After install the command is nvm. Versions live in ~/.nvm. Node downloads come from npmmirror. With no arguments it opens a guide, and scope routes can be written for npm, yarn, pnpm, and bun."}
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href={zh ? "/zh/getting-started" : "/getting-started"}>
                <Button size="lg" className="bg-node text-[#041208] hover:bg-[#43a843]">
                  {zh ? "快速开始" : "Get started"}
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </Link>
              <Link href="https://github.com/charlzyx/znvm" target="_blank" rel="noopener noreferrer">
                <Button size="lg" variant="outline" className="border-white/15 bg-transparent">
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
