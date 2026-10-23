"use client";

import Link from "next/link";
import { ArrowRight, Github } from "@/components/icons";
import { Button } from "@/components/ui/button";
import { TypingTerminal } from "@/components/typing-terminal";

export function Hero({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";

  return (
    <section className="relative overflow-hidden border-b border-border">
      <div className="container relative pt-12 pb-10 sm:pt-14 sm:pb-12 lg:pt-16 lg:pb-14">
        <div className="grid min-w-0 items-start gap-10 lg:grid-cols-2 lg:gap-16">
          <div className="min-w-0">
            <p className="zig-mark">{zh ? "用 Zig 构建" : "Built with Zig"}</p>
            <h1 className="mt-5 font-semibold leading-[0.92] tracking-[-0.045em] text-[clamp(3.5rem,6.5vw,6rem)]">
              znvm
            </h1>
            <p className="mt-5 max-w-[58ch] text-lg leading-relaxed text-foreground">
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
