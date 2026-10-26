"use client";

import Link from "next/link";

const version = "v2.10.0";

export function Hero({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const startHref = zh ? "/zh/getting-started" : "/getting-started";
  const windowsHref = zh ? "/zh/windows" : "/windows";
  const releaseBase = `https://github.com/charlzyx/znvm/releases/download/${version}`;

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
      <p className="mt-6 text-xs text-muted-foreground">macOS · Linux</p>
      <p className="mt-2 overflow-x-auto font-mono text-[13px] text-foreground">
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
      <div className="mt-10 max-w-2xl border-t border-border pt-6">
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <h2 className="kicker">Windows · x64 / ARM64</h2>
          <Link href={windowsHref} className="text-sm underline underline-offset-4 hover:text-muted-foreground">
            {zh ? "Windows 安装指南" : "Windows setup"}
          </Link>
        </div>
        <div className="mt-4 grid grid-cols-1 border-l border-t border-border sm:grid-cols-2">
          {[
            { name: "Windows x64", target: "x86_64", detail: zh ? "Intel / AMD · ZIP 下载" : "Intel / AMD · Download ZIP" },
            { name: "Windows ARM64", target: "aarch64", detail: zh ? "ARM 设备 · ZIP 下载" : "ARM devices · Download ZIP" },
          ].map((platform) => (
            <a key={platform.target}
              href={`${releaseBase}/znvm-${version}-${platform.target}-windows.zip`}
              className="min-w-0 border-r border-b border-border p-4 transition-colors hover:bg-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring">
              <span className="block text-sm font-semibold">{platform.name} <span aria-hidden="true">↓</span></span>
              <span className="mt-1 block text-xs leading-relaxed text-muted-foreground">{platform.detail}</span>
            </a>
          ))}
        </div>
        <p className="mt-3 text-xs leading-relaxed text-muted-foreground">
          {zh ? "PowerShell 7、cmd、Git Bash。无需管理员权限，只切换当前终端。" : "PowerShell 7, cmd, Git Bash. No admin rights; switches only this terminal."}{" "}
          <a href={`${releaseBase}/SHA256SUMS`} className="underline underline-offset-4">SHA256SUMS</a>
        </p>
      </div>
    </section>
  );
}
