"use client";

const features = {
  en: [
    {
      title: "nvm",
      body: "install-as-nvm.sh installs nvm and links nrm. Versions live in ~/.nvm.",
    },
    {
      title: "npmmirror",
      body: "Node archives come from https://npmmirror.com/mirrors/node. Override with NVM_NODEJS_ORG_MIRROR.",
    },
    {
      title: "Guide",
      body: "nvm with no arguments opens a number menu. No terminal: it prints a notice and exits.",
    },
    {
      title: "Registries",
      body: "nrm sets the npm registry and @scope routes for npm, yarn, pnpm, and bun.",
    },
    {
      title: "Mirrors",
      body: "nvm mirror sets download hosts for Electron, Playwright, and the other tools.",
    },
    {
      title: "Agents",
      body: "nvm --llm prints this guide. --json prints one object. CI, --yes, or NVM_NONINTERACTIVE=1 skips menus. No MCP server.",
    },
  ],
  zh: [
    {
      title: "nvm",
      body: "install-as-nvm.sh 安装 nvm，并把 nrm 链到同一文件。版本在 ~/.nvm。",
    },
    {
      title: "npmmirror",
      body: "Node 压缩包来自 https://npmmirror.com/mirrors/node。换地址用 NVM_NODEJS_ORG_MIRROR。",
    },
    {
      title: "引导",
      body: "不带参数的 nvm 打开数字菜单。没有终端时只打印一句说明并退出。",
    },
    {
      title: "源",
      body: "nrm 设置 npm 源和 @scope，并写入 npm、yarn、pnpm、bun。",
    },
    {
      title: "镜像",
      body: "nvm mirror 设置 Electron、Playwright 和其他工具的下载地址。",
    },
    {
      title: "Agent",
      body: "nvm --llm 打印这份说明。--json 打一个对象。CI、--yes 或 NVM_NONINTERACTIVE=1 不打开菜单。没有 MCP。",
    },
  ],
};

export function Features({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const items = zh ? features.zh : features.en;

  return (
    <section className="border-b-2 border-border py-16 sm:py-24">
      <div className="container">
        <h2 className="text-4xl font-black tracking-tight sm:text-5xl">
          {zh ? "功能" : "Features"}
        </h2>
        <div className="mt-12 border-2 border-border">
          {items.map((item) => (
            <article key={item.title} className="grid min-w-0 border-b-2 border-border last:border-b-0 md:grid-cols-[18rem_1fr]">
              <h3 className="border-b-2 border-border p-6 text-3xl font-black tracking-tight text-node-bright sm:p-8 md:border-r-2 md:border-b-0">
                {item.title}
              </h3>
              <p className="max-w-[65ch] px-6 pb-8 text-lg leading-7 text-foreground [overflow-wrap:anywhere] sm:px-8 md:py-8">{item.body}</p>
            </article>
          ))}
        </div>
        <p className="mt-8 text-base text-muted-foreground">
          {zh
            ? "不设置 Docker 镜像。那要改 daemon 配置并重启。"
            : "Docker image mirrors are not set here. That needs a daemon config and a restart."}
        </p>
      </div>
    </section>
  );
}
