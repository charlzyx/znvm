"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { Menu, Github, Zap } from "lucide-react";

interface NavLink {
  href: string;
  label: string;
  labelZh: string;
}

const navLinks: NavLink[] = [
  { href: "/", label: "Home", labelZh: "首页" },
  { href: "/getting-started", label: "Docs", labelZh: "文档" },
  { href: "/blog/why-zig", label: "Blog", labelZh: "博客" },
];

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

  return (
    <header className="sticky top-0 z-50 w-full border-b border-border/40 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container flex h-14 items-center">
        {/* Logo */}
        <Link href={homeHref} className="mr-6 flex items-center space-x-2 flex-shrink-0">
          <Zap className="h-6 w-6 text-orange-500" />
          <span className="font-bold text-xl">znvm</span>
        </Link>

        {/* Desktop Navigation */}
        <nav className="hidden md:flex items-center space-x-6 text-sm font-medium">
          {navLinks.map((link) => (
            <Link
              key={link.href}
              href={getNavHref(link, isZh)}
              className="transition-colors hover:text-foreground/80 text-foreground/60"
            >
              {isZh ? link.labelZh : link.label}
            </Link>
          ))}
        </nav>

        {/* Right side */}
        <div className="flex flex-1 items-center justify-end space-x-4">
          {/* Language switcher */}
          <nav className="hidden md:flex items-center space-x-4">
            <Link href="/" className={`text-sm transition-colors ${!isZh ? "text-foreground font-medium" : "text-foreground/60 hover:text-foreground"}`}>
              English
            </Link>
            <Link href="/zh" className={`text-sm transition-colors ${isZh ? "text-foreground font-medium" : "text-foreground/60 hover:text-foreground"}`}>
              中文
            </Link>
          </nav>

          {/* GitHub */}
          <Link href="https://github.com/charlzyx/znvm" target="_blank" rel="noopener noreferrer">
            <Button variant="ghost" size="icon" className="h-8 w-8">
              <Github className="h-4 w-4" />
              <span className="sr-only">GitHub</span>
            </Button>
          </Link>

          {/* Mobile menu */}
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
        <Zap className="h-5 w-5 text-orange-500" />
        <span className="font-bold">znvm</span>
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

      {/* GitHub */}
      <div className="border-t pt-4">
        <Link href="https://github.com/charlzyx/znvm" target="_blank" rel="noopener noreferrer" className="text-foreground/60 hover:text-foreground transition-colors">
          GitHub
        </Link>
      </div>
    </div>
  );
}
