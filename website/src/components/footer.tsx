"use client";

import Link from "next/link";
import { Zap, Github, Twitter, Heart } from "lucide-react";
import { Separator } from "@/components/ui/separator";

interface FooterProps {
  lang?: "en" | "zh";
}

export function Footer({ lang = "en" }: FooterProps) {
  const isZh = lang === "zh";

  return (
    <footer className="border-t bg-muted/50">
      <div className="container py-12">
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          {/* Brand */}
          <div>
            <Link href={isZh ? "/zh" : "/"} className="flex items-center space-x-2">
              <Zap className="h-5 w-5 text-orange-500" />
              <span className="font-bold">znvm</span>
            </Link>
            <p className="mt-4 text-sm text-muted-foreground">
              {isZh
                ? "零负担 Node 版本管理器，基于 Zig 构建"
                : "Zero-overhead Node Version Manager, built with Zig"
              }
            </p>
          </div>

          {/* Links */}
          <div>
            <h3 className="font-semibold mb-3">
              {isZh ? "文档" : "Documentation"}
            </h3>
            <ul className="space-y-2 text-sm">
              <li>
                <Link href={isZh ? "/zh/getting-started" : "/getting-started"} className="text-muted-foreground hover:text-foreground">
                  {isZh ? "快速开始" : "Getting Started"}
                </Link>
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

        <Separator className="my-8" />

        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 text-sm text-muted-foreground">
          <p>
            © {new Date().getFullYear()} znvm. {isZh ? "保留所有权利" : "All rights reserved"}.
          </p>
          <p className="flex items-center">
            {isZh ? "用" : "Made with"} <Heart className="mx-1 h-4 w-4 text-red-500" /> {isZh ? "和 Zig 构建" : "and Zig"}
          </p>
        </div>
      </div>
    </footer>
  );
}
