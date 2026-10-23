"use client";

import { IconAgent, IconDownload, IconGuide, IconMirror, IconNvm, IconRegistry } from "@/components/icons";

const icons = [IconNvm, IconMirror, IconGuide, IconRegistry, IconDownload, IconAgent];

const features = {
  en: [
    {
      title: "NVM",
      body: "install-as-nvm.sh installs NVM and links NRM. Versions stay in ~/.nvm.",
    },
    {
      title: "npmmirror",
      body: "Node archives come from npmmirror. Set NVM_NODEJS_ORG_MIRROR to change the host.",
    },
    {
      title: "Guide",
      body: "Run nvm and pick a number. With no terminal it prints one line and exits.",
    },
    {
      title: "Registries",
      body: "NRM sets the npm registry and @scope routes for npm, yarn, pnpm, and bun.",
    },
    {
      title: "Mirrors",
      body: "nvm mirror sets download hosts for Electron, Playwright, and the rest.",
    },
    {
      title: "Agents",
      body: "nvm --llm prints the guide. --json prints one object. CI, --yes, or NVM_NONINTERACTIVE=1 skips menus. No MCP server.",
    },
  ],
  zh: [
    {
      title: "NVM",
      body: "install-as-nvm.sh 装上 NVM，并链出 NRM。版本仍在 ~/.nvm。",
    },
    {
      title: "npmmirror",
      body: "Node 包从 npmmirror 下。要换地址，设 NVM_NODEJS_ORG_MIRROR。",
    },
    {
      title: "引导",
      body: "直接敲 nvm，用数字选。没有终端就只打一行，然后退出。",
    },
    {
      title: "源",
      body: "NRM 管 npm 源和 @scope，写入 npm、yarn、pnpm、bun。",
    },
    {
      title: "镜像",
      body: "用 nvm mirror 换 Electron、Playwright 这些下载地址。",
    },
    {
      title: "Agent",
      body: "nvm --llm 打出这份说明。--json 打一个对象。CI、--yes 或 NVM_NONINTERACTIVE=1 时不进菜单。没有 MCP。",
    },
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
            return (
              <article key={item.title} className="min-w-0 border-r border-b border-border p-6">
                <Icon className="size-4 text-muted-foreground" />
                <h3 className="mt-4 text-base font-semibold tracking-tight">{item.title}</h3>
                <p className="mt-2 text-base leading-relaxed text-muted-foreground [overflow-wrap:anywhere]">{item.body}</p>
              </article>
            );
          })}
        </div>
        <p className="mt-8 text-base leading-relaxed text-muted-foreground">
          {zh
            ? "不管 Docker 镜像。那要改 daemon 配置，再重启。"
            : "Docker image mirrors stay out of this page. That needs a daemon config and a restart."}
        </p>
      </div>
    </section>
  );
}
