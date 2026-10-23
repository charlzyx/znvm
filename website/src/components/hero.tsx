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
                ? "命令是 nvm 和 nrm。版本在 ~/.nvm。Node 从 npmmirror 下载。"
                : "Commands are nvm and nrm. Versions live in ~/.nvm. Node downloads come from npmmirror."}
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href={zh ? "/zh/getting-started" : "/getting-started"}>
                <Button size="lg" className="bg-node text-[#041208] hover:bg-[#43a843]">
                  {zh ? "快速开始" : "Quick start"}
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </Link>
              <a href="https://znvm.dev/llm.txt">
                <Button size="lg" variant="outline" className="border-white/15 bg-transparent">
                  {zh ? "给 Agent" : "For Agents"}
                </Button>
              </a>
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
