"use client";

import { IconDownload, IconGuide, IconMirror, IconNvm, IconRegistry } from "@/components/icons";

const icons = [IconNvm, IconMirror, IconGuide, IconRegistry, IconDownload];

const features = {
  en: [
    { title: "NVM", body: "Same commands you already know." },
    { title: "npmmirror", body: "Node downloads, already mirrored." },
    { title: "Guide", body: "A menu instead of flags." },
    { title: "Registries", body: "One command changes the registry." },
    { title: "Mirrors", body: "Electron and Playwright, mirrored." },
  ],
  zh: [
    { title: "NVM", body: "命令和原来一样" },
    { title: "npmmirror", body: "Node 下载走国内" },
    { title: "引导", body: "菜单里直接选" },
    { title: "源", body: "一条命令换源" },
    { title: "镜像", body: "二进制也走国内" },
  ],
};

export function Features({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const items = zh ? features.zh : features.en;

  return (
    <section className="border-t border-border py-14 md:py-16">
      <div className="container">
        <h2 className="kicker">{zh ? "功能" : "Features"}</h2>
        <div className="mt-6 grid grid-cols-1 border-l border-t border-border sm:grid-cols-2 lg:grid-cols-3">
          {items.map((item, index) => {
            const Icon = icons[index];
            const span = index === items.length - 1 ? "sm:col-span-2 lg:col-span-2" : "";
            return (
              <article key={item.title} className={`min-w-0 border-r border-b border-border p-6 ${span}`}>
                <Icon className="size-4 text-muted-foreground" />
                <h3 className="mt-4 text-base font-semibold tracking-tight">{item.title}</h3>
                <p className="mt-2 text-base leading-relaxed text-muted-foreground [overflow-wrap:anywhere]">{item.body}</p>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}
