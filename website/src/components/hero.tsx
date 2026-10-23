"use client";

import Link from "next/link";

const version = "v2.9.0";

export function Hero({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const startHref = zh ? "/zh/getting-started" : "/getting-started";

  return (
    <section className="container pt-14 pb-16 md:pt-20 md:pb-20">
      <p className="zig-mark">{zh ? "用 Zig 写的" : "Built with Zig"}</p>
      <h1 className="mt-6 max-w-4xl text-[2.6rem] font-semibold leading-[1.02] tracking-[-0.04em] text-balance md:text-[3.5rem]">
        {zh ? (
          <>
            NVM 的命令，
            <br />
            原生的速度。
          </>
        ) : (
          <>
            NVM commands.
            <br />
            Native speed.
          </>
        )}
      </h1>
      <p className="mt-5 max-w-[36rem] text-[17px] font-normal leading-relaxed text-pretty text-muted-foreground">
        {zh
          ? "命令不变，目录不变，国内镜像开箱即用。"
          : "Same commands, same ~/.nvm, China mirrors built in."}
      </p>
      <p className="mt-6 overflow-x-auto font-mono text-[13px] text-foreground">
        curl -fsSL https://znvm.dev/install.sh | bash
      </p>
      <div className="mt-8 flex flex-wrap items-center gap-x-5 gap-y-3">
        <Link
          href={startHref}
          className="inline-flex h-10 items-center bg-foreground px-4 text-sm font-medium text-background hover:opacity-90"
        >
          {zh ? "快速开始" : "Quick start"}
        </Link>
        <span className="font-mono text-[13px] text-muted-foreground">{version}</span>
        <a href="https://znvm.dev/llm.txt" className="text-sm text-muted-foreground hover:text-foreground">
          {zh ? "给 Agent" : "For Agents"}
        </a>
      </div>
    </section>
  );
}
