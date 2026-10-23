"use client";

import { Moon, Sun } from "@/components/icons";
import { themeStorageKey } from "@/lib/theme";

function applyTheme(theme: "light" | "dark") {
  const root = document.documentElement;
  root.classList.remove("light", "dark");
  root.classList.add(theme);
  root.style.colorScheme = theme;
  localStorage.setItem(themeStorageKey, theme);
}

export function ThemeToggle({ isZh, labeled = false }: { isZh: boolean; labeled?: boolean }) {
  const labelClass = labeled ? "inline" : "hidden md:inline";

  return (
    <button
      type="button"
      onClick={() => {
        const next = document.documentElement.classList.contains("dark") ? "light" : "dark";
        applyTheme(next);
      }}
      aria-label={isZh ? "切换浅色或深色" : "Toggle light or dark theme"}
      className="inline-flex h-8 items-center gap-2 border border-border bg-background px-2 text-sm font-medium text-foreground hover:bg-muted focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#339933]"
    >
      <Sun className="hidden size-4 dark:block" aria-hidden="true" />
      <Moon className="size-4 dark:hidden" aria-hidden="true" />
      <span className={labelClass}>
        <span className="hidden dark:inline">{isZh ? "深色" : "Dark"}</span>
        <span className="dark:hidden">{isZh ? "浅色" : "Light"}</span>
      </span>
    </button>
  );
}
