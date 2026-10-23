"use client";

import Link from "next/link";
import { LogoMark } from "@/components/logo-mark";

interface FooterProps {
  lang?: "en" | "zh";
}

export function Footer({ lang = "en" }: FooterProps) {
  const isZh = lang === "zh";

  return (
    <footer className="border-t border-border">
      <div className="container py-16">
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {/* Brand */}
          <div>
            <Link href={isZh ? "/zh" : "/"} className="flex items-center space-x-2">
              <LogoMark className="h-5 w-5" />
              <span className="font-semibold tracking-tight">znvm</span>
            </Link>
            <p className="zig-mark mt-5">{isZh ? "用 Zig 构建" : "Built with Zig"}</p>
          </div>

          {/* Links */}
          <div>
            <h3 className="font-semibold mb-3">
              {isZh ? "文档" : "Documentation"}
            </h3>
            <ul className="space-y-2 text-sm">
              <li>
                <Link href={isZh ? "/zh/getting-started" : "/getting-started"} className="text-muted-foreground hover:text-foreground">
                  {isZh ? "快速开始" : "Quick start"}
                </Link>
              </li>
              <li>
                <a href="https://znvm.dev/llm.txt" className="text-muted-foreground hover:text-foreground">
                  {isZh ? "给 Agent" : "For Agents"}
                </a>
              </li>
              <li>
                <Link href={isZh ? "/zh/blog/why-zig" : "/blog/why-zig"} className="text-muted-foreground hover:text-foreground">
                  {isZh ? "为什么选 Zig" : "Why Zig?"}
                </Link>
              </li>
            </ul>
          </div>

          {/* Community */}
          <div>
            <h3 className="font-semibold mb-3">
              {isZh ? "社区" : "Community"}
            </h3>
            <ul className="space-y-2 text-sm">
              <li>
                <Link href="https://github.com/charlzyx/znvm" target="_blank" className="text-muted-foreground hover:text-foreground">
                  GitHub
                </Link>
              </li>
              <li>
                <Link href="https://github.com/charlzyx/znvm/issues" target="_blank" className="text-muted-foreground hover:text-foreground">
                  {isZh ? "问题反馈" : "Issues"}
                </Link>
              </li>
            </ul>
          </div>

          {/* Language */}
          <div>
            <h3 className="font-semibold mb-3">
              {isZh ? "语言" : "Language"}
            </h3>
            <ul className="space-y-2 text-sm">
              <li>
                <Link href="/" className={`${!isZh ? "text-foreground font-medium" : "text-muted-foreground"} hover:text-foreground`}>
                  English
                </Link>
              </li>
              <li>
                <Link href="/zh" className={`${isZh ? "text-foreground font-medium" : "text-muted-foreground"} hover:text-foreground`}>
                  简体中文
                </Link>
              </li>
            </ul>
          </div>
        </div>

        <div className="my-8 border-t border-border" />

        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 text-sm text-muted-foreground">
          <p>
            © {new Date().getFullYear()} znvm. {isZh ? "保留所有权利" : "All rights reserved"}.
          </p>
          <p>Linux, macOS</p>
        </div>
      </div>
    </footer>
  );
}
