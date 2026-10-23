"use client";

import Link from "next/link";

const version = "v2.8.0";

export function Hero({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const startHref = zh ? "/zh/getting-started" : "/getting-started";

  return (
    <section className="container pt-14 pb-16 md:pt-20 md:pb-20">
      <p className="zig-mark">{zh ? "用 Zig 构建" : "Built with Zig"}</p>
      <h1 className="mt-6 max-w-4xl text-[2.6rem] font-bold leading-[1.02] tracking-[-0.035em] text-balance md:text-[3.5rem]">
        {zh ? (
          <>
            nvm 和 nrm，
            <br />
            用 Zig 写成。
          </>
        ) : (
          <>
            nvm and nrm,
            <br />
            written in Zig.
          </>
        )}
      </h1>
      <p className="mt-5 max-w-[36rem] text-[17px] leading-relaxed text-pretty text-muted-foreground">
        {zh
          ? "版本在 ~/.nvm。Node 从 npmmirror 下载。"
          : "Versions live in ~/.nvm. Node downloads come from npmmirror."}
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
