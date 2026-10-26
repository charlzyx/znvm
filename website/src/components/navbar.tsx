"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { Menu, Github } from "@/components/icons";
import { LogoMark } from "@/components/logo-mark";
import { ThemeToggle } from "@/components/theme-toggle";

interface NavLink {
  href: string;
  label: string;
  labelZh: string;
}

const navLinks: NavLink[] = [
  { href: "/", label: "Home", labelZh: "首页" },
  { href: "/getting-started", label: "Docs", labelZh: "文档" },
  { href: "/windows", label: "Windows", labelZh: "Windows" },
  { href: "/blog/why-zig", label: "Blog", labelZh: "博客" },
];

const agentsHref = "https://znvm.dev/llm.txt";

const getNavHref = (link: NavLink, isZh: boolean): string => {
  if (isZh) {
    return link.href === "/" ? "/zh" : `/zh${link.href}`;
  }
  return link.href;
};

export function Navbar() {
  const pathname = usePathname();
  const isZh = pathname.startsWith("/zh");
  const homeHref = isZh ? "/zh" : "/";

  const startHref = isZh ? "/zh/getting-started" : "/getting-started";

  return (
    <header className="sticky top-0 z-50 w-full border-b border-border bg-background">
      <div className="container flex h-14 items-center">
        <Link href={homeHref} className="mr-6 flex items-center gap-2 flex-shrink-0">
          <LogoMark className="h-5 w-5" />
          <span className="text-[15px] font-semibold tracking-[-0.04em]">ZNVM</span>
        </Link>

        <div className="flex flex-1 items-center justify-end gap-4">
          <nav className="hidden items-center gap-3 md:flex">
            <Link href={isZh ? "/zh/windows" : "/windows"} className="text-sm text-muted-foreground hover:text-foreground">
              Windows
            </Link>
            <Link href="/" className={`text-sm ${!isZh ? "text-foreground" : "text-muted-foreground hover:text-foreground"}`}>
              English
            </Link>
            <Link href="/zh" className={`text-sm ${isZh ? "text-foreground" : "text-muted-foreground hover:text-foreground"}`}>
              中文
            </Link>
            <a href={agentsHref} className="text-sm text-muted-foreground hover:text-foreground">
              {isZh ? "给 Agent" : "For Agents"}
            </a>
          </nav>

          <ThemeToggle isZh={isZh} />

          <Link href="https://github.com/charlzyx/znvm" target="_blank" rel="noopener noreferrer" className="text-muted-foreground hover:text-foreground">
            <Github className="h-4 w-4" />
            <span className="sr-only">GitHub</span>
          </Link>

          <Link
            href={startHref}
            className="inline-flex h-8 items-center bg-foreground px-3 text-[13px] font-medium text-background hover:opacity-90"
          >
            {isZh ? "快速开始" : "Quick start"}
          </Link>

          <Sheet>
            <SheetTrigger className="md:hidden h-8 w-8 p-0 inline-flex items-center justify-center rounded-md border border-input bg-background hover:bg-muted">
              <Menu className="h-4 w-4" />
              <span className="sr-only">Toggle menu</span>
            </SheetTrigger>
            <SheetContent side="right" className="pr-0">
              <MobileNav isZh={isZh} />
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </header>
  );
}

function MobileNav({ isZh }: { isZh: boolean }) {
  const homeHref = isZh ? "/zh" : "/";

  return (
    <div className="flex flex-col space-y-4 p-4">
      {/* Logo */}
      <Link href={homeHref} className="flex items-center space-x-2">
        <LogoMark className="h-5 w-5" />
        <span className="font-semibold tracking-[-0.04em]">ZNVM</span>
      </Link>

      {/* Navigation */}
      <nav className="flex flex-col space-y-2">
        {navLinks.map((link) => (
          <Link
            key={link.href}
            href={getNavHref(link, isZh)}
            className="px-2 py-1 text-foreground/60 hover:text-foreground transition-colors"
          >
            {isZh ? link.labelZh : link.label}
          </Link>
        ))}
      </nav>

      {/* Language */}
      <div className="border-t pt-4">
        <div className="text-sm font-medium mb-2">Language / 语言</div>
        <div className="flex flex-col space-y-1">
          <Link href="/" className={`px-2 py-1 ${!isZh ? "text-foreground font-medium" : "text-foreground/60"}`}>
            English
          </Link>
          <Link href="/zh" className={`px-2 py-1 ${isZh ? "text-foreground font-medium" : "text-foreground/60"}`}>
            中文
          </Link>
        </div>
      </div>

      <div className="border-t pt-4">
        <a href={agentsHref} className="text-foreground/80 hover:text-foreground">
          {isZh ? "给 Agent" : "For Agents"}
        </a>
      </div>

      <div className="border-t pt-4">
        <ThemeToggle isZh={isZh} labeled />
      </div>

      {/* GitHub */}
      <div className="border-t pt-4">
        <Link href="https://github.com/charlzyx/znvm" target="_blank" rel="noopener noreferrer" className="text-foreground/60 hover:text-foreground transition-colors">
          GitHub
        </Link>
      </div>
    </div>
  );
}
